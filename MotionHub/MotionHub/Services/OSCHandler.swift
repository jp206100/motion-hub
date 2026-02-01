//
//  OSCHandler.swift
//  Motion Hub
//
//  OSC (Open Sound Control) server for external control via Max for Live
//
//  BUILD MARKER: 2026-02-01-v2 - Debug integer handling for glitch/colorshift
//

import Foundation
import Combine

class OSCHandler: ObservableObject {
    // MARK: - Published Properties
    @Published var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                startServer()
            } else {
                stopServer()
            }
        }
    }
    @Published var port: UInt16 = 9000 {
        didSet {
            if isEnabled {
                restartServer()
            }
        }
    }
    @Published var isConnected: Bool = false
    @Published var lastMessageTime: Date?
    @Published var messageCount: Int = 0

    // MARK: - State Reference
    weak var appState: AppState?

    // MARK: - Network
    private var socketFD: Int32 = -1
    private var receiveThread: Thread?
    private var shouldStop = false

    // MARK: - OSC Address Mappings
    enum OSCAddress: String, CaseIterable {
        case intensity = "/motionhub/intensity"
        case glitchAmount = "/motionhub/glitch"
        case speed = "/motionhub/speed"
        case colorShift = "/motionhub/colorshift"
        case freqMin = "/motionhub/freqmin"
        case freqMax = "/motionhub/freqmax"
        case monochrome = "/motionhub/monochrome"
        case reset = "/motionhub/reset"

        // Aliases for convenience
        static func fromString(_ address: String) -> OSCAddress? {
            // Exact match
            if let exact = OSCAddress(rawValue: address.lowercased()) {
                return exact
            }
            // Common aliases
            switch address.lowercased() {
            case "/motionhub/glitchamount": return .glitchAmount
            case "/motionhub/color": return .colorShift
            case "/motionhub/color_shift": return .colorShift
            case "/motionhub/freq_min": return .freqMin
            case "/motionhub/freq_max": return .freqMax
            case "/motionhub/mono": return .monochrome
            default: return nil
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Start server after a brief delay to allow app initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if self?.isEnabled == true {
                self?.startServer()
            }
        }
    }

    deinit {
        stopServer()
    }

    // MARK: - Server Management

    func startServer() {
        guard socketFD == -1 else { return }

        // Create UDP socket
        socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else {
            print("❌ OSC: Failed to create socket")
            DispatchQueue.main.async {
                self.isConnected = false
            }
            return
        }

        // Allow address reuse
        var yes: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        // Set receive timeout to allow clean shutdown
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Bind to port
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if bindResult < 0 {
            print("❌ OSC: Failed to bind to port \(port) - error \(errno)")
            close(socketFD)
            socketFD = -1
            DispatchQueue.main.async {
                self.isConnected = false
            }
            return
        }

        print("🎛️ OSC server listening on port \(port)")
        DispatchQueue.main.async {
            self.isConnected = true
        }

        // Start receive thread
        shouldStop = false
        receiveThread = Thread { [weak self] in
            self?.receiveLoop()
        }
        receiveThread?.name = "OSC Receive Thread"
        receiveThread?.start()
    }

    func stopServer() {
        shouldStop = true

        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }

        receiveThread = nil

        DispatchQueue.main.async {
            self.isConnected = false
        }
        print("🛑 OSC server stopped")
    }

    private func restartServer() {
        stopServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startServer()
        }
    }

    // MARK: - Receive Loop

    private func receiveLoop() {
        var buffer = [UInt8](repeating: 0, count: 2048)

        while !shouldStop && socketFD >= 0 {
            let bytesRead = recv(socketFD, &buffer, buffer.count, 0)

            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                parseOSCMessage(data)
            } else if bytesRead < 0 {
                // Timeout (EAGAIN/EWOULDBLOCK) is expected - just continue
                if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR {
                    if !shouldStop {
                        print("❌ OSC: Receive error \(errno)")
                    }
                    break
                }
                // Timeout reached, just loop and check shouldStop
            }
        }
    }

    // MARK: - OSC Parsing

    /// Parse text-based OSC message (e.g., "/motionhub/intensity 0.5")
    /// This handles messages from Max/MSP which sends address and value as a single string
    private func parseTextMessage(_ message: String) {
        let components = message.split(separator: " ", maxSplits: 1)
        guard components.count >= 1 else { return }

        let address = String(components[0])
        var arguments: [Any] = []

        if components.count >= 2 {
            let valueString = String(components[1])
            if let floatValue = Float(valueString) {
                arguments.append(floatValue)
            } else if let intValue = Int32(valueString) {
                arguments.append(intValue)
            }
        }

        handleOSCMessage(address: address, arguments: arguments)
    }

    private func parseOSCMessage(_ data: Data) {
        guard data.count >= 4 else {
            return
        }

        var offset = 0

        // Parse address pattern (null-terminated, padded to 4 bytes)
        guard let address = readOSCString(from: data, offset: &offset) else {
            return
        }

        // Check if this is a text-based message (address contains space + value)
        // Max/MSP sends "/motionhub/intensity 0.5" as a single string
        if address.contains(" ") {
            parseTextMessage(address)
            return
        }

        // Parse type tag string (starts with ',')
        guard let typeTag = readOSCString(from: data, offset: &offset),
              typeTag.hasPrefix(",") else {
            print("🎛️ OSC: Failed to parse type tag")
            return
        }
        print("🎛️ OSC: Type tag = '\(typeTag)'")

        // Parse arguments based on type tags
        var arguments: [Any] = []
        let types = String(typeTag.dropFirst()) // Remove leading ','

        for type in types {
            switch type {
            case "f": // Float32
                if let value = readOSCFloat(from: data, offset: &offset) {
                    arguments.append(value)
                    print("🎛️ OSC: Float arg = \(value)")
                }
            case "i": // Int32
                if let value = readOSCInt(from: data, offset: &offset) {
                    arguments.append(value)
                    print("🎛️ OSC: Int arg = \(value)")
                }
            case "s": // String
                if let value = readOSCString(from: data, offset: &offset) {
                    arguments.append(value)
                    print("🎛️ OSC: String arg = \(value)")
                }
            case "T": // True
                arguments.append(true)
                print("🎛️ OSC: Bool arg = true")
            case "F": // False
                arguments.append(false)
                print("🎛️ OSC: Bool arg = false")
            default:
                print("🎛️ OSC: Unknown type tag '\(type)'")
                break
            }
        }

        // Handle the message
        print("🎛️ OSC: Handling message with \(arguments.count) arguments")
        handleOSCMessage(address: address, arguments: arguments)
    }

    private func readOSCString(from data: Data, offset: inout Int) -> String? {
        var endIndex = offset
        while endIndex < data.count && data[endIndex] != 0 {
            endIndex += 1
        }

        guard endIndex > offset else { return nil }

        let stringData = data[offset..<endIndex]
        let string = String(data: stringData, encoding: .utf8)

        // Pad to 4-byte boundary
        offset = ((endIndex + 4) / 4) * 4

        return string
    }

    private func readOSCFloat(from data: Data, offset: inout Int) -> Float? {
        guard offset + 4 <= data.count else { return nil }

        let bytes = data[offset..<(offset + 4)]
        offset += 4

        // OSC uses big-endian
        let value = bytes.withUnsafeBytes { ptr in
            Float(bitPattern: UInt32(bigEndian: ptr.load(as: UInt32.self)))
        }

        return value
    }

    private func readOSCInt(from data: Data, offset: inout Int) -> Int32? {
        guard offset + 4 <= data.count else { return nil }

        let bytes = data[offset..<(offset + 4)]
        offset += 4

        // OSC uses big-endian
        let value = bytes.withUnsafeBytes { ptr in
            Int32(bigEndian: ptr.load(as: Int32.self))
        }

        return value
    }

    // MARK: - Message Handling

    private func handleOSCMessage(address: String, arguments: [Any]) {
        print("🎛️ OSC: handleOSCMessage called with address '\(address)'")

        guard let oscAddress = OSCAddress.fromString(address) else {
            print("🎛️ OSC: Unknown address '\(address)' - ignoring")
            return
        }
        print("🎛️ OSC: Mapped to \(oscAddress)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("🎛️ OSC: self is nil")
                return
            }
            guard let appState = self.appState else {
                print("🎛️ OSC: appState is nil!")
                return
            }
            print("🎛️ OSC: Updating appState for \(oscAddress)")

            self.lastMessageTime = Date()
            self.messageCount += 1

            switch oscAddress {
            case .intensity:
                if let value = self.extractFloat(from: arguments) {
                    // Normalize: accept 0-1 or 0-100 range
                    let normalized: Float
                    if value > 1.0 && value <= 100.0 {
                        normalized = value / 100.0
                    } else if value > 100.0 {
                        normalized = 1.0
                    } else {
                        normalized = value
                    }
                    appState.intensity = Double(clamp(normalized, min: 0, max: 1))
                }

            case .glitchAmount:
                // Handle both float and integer input from OSC
                var rawValue: Float?
                let firstArg = arguments.first
                print("🎛️ OSC: glitchAmount arg type: \(type(of: firstArg)), value: \(String(describing: firstArg))")

                if let intVal = firstArg as? Int32 {
                    rawValue = Float(intVal)
                    print("🎛️ OSC: Converted Int32 \(intVal) to Float \(rawValue!)")
                } else if let intVal = firstArg as? Int {
                    rawValue = Float(intVal)
                    print("🎛️ OSC: Converted Int \(intVal) to Float \(rawValue!)")
                } else if let floatVal = firstArg as? Float {
                    rawValue = floatVal
                    print("🎛️ OSC: Got Float \(floatVal)")
                } else if let doubleVal = firstArg as? Double {
                    rawValue = Float(doubleVal)
                    print("🎛️ OSC: Converted Double \(doubleVal) to Float \(rawValue!)")
                } else {
                    rawValue = self.extractFloat(from: arguments)
                    print("🎛️ OSC: extractFloat returned \(String(describing: rawValue))")
                }

                if let value = rawValue {
                    // Normalize: accept 0-1 or 0-100 range
                    let normalized: Float
                    if value > 1.0 && value <= 100.0 {
                        normalized = value / 100.0
                    } else if value > 100.0 {
                        normalized = 1.0
                    } else {
                        normalized = value
                    }
                    appState.glitchAmount = Double(clamp(normalized, min: 0, max: 1))
                    print("🎛️ OSC: Set glitchAmount to \(appState.glitchAmount) (raw: \(value), normalized: \(normalized))")
                }

            case .speed:
                if let value = self.extractFloat(from: arguments) {
                    // Map 0-1 to 1-4, or accept direct 1-4 values
                    if value <= 1.0 {
                        appState.speed = Int(value * 3) + 1
                    } else {
                        appState.speed = Int(clamp(value, min: 1, max: 4))
                    }
                    print("🎛️ OSC: Set speed to \(appState.speed)")
                } else if let value = self.extractInt(from: arguments) {
                    appState.speed = Int(clamp(Float(value), min: 1, max: 4))
                    print("🎛️ OSC: Set speed to \(appState.speed)")
                }

            case .colorShift:
                // Handle both float and integer input from OSC
                var rawValue: Float?
                if let intVal = arguments.first as? Int32 {
                    rawValue = Float(intVal)
                } else if let intVal = arguments.first as? Int {
                    rawValue = Float(intVal)
                } else {
                    rawValue = self.extractFloat(from: arguments)
                }

                if let value = rawValue {
                    // Normalize: accept 0-1 or 0-100 range
                    let normalized: Float
                    if value > 1.0 && value <= 100.0 {
                        normalized = value / 100.0
                    } else if value > 100.0 {
                        normalized = 1.0
                    } else {
                        normalized = value
                    }
                    appState.colorShift = Double(clamp(normalized, min: 0, max: 1))
                    print("🎛️ OSC: Set colorShift to \(appState.colorShift) (raw: \(value))")
                }

            case .freqMin:
                if let value = self.extractFloat(from: arguments) {
                    // Accept either 0-1 normalized or direct Hz value
                    if value <= 1.0 {
                        appState.freqMin = mapToFrequency(value)
                    } else {
                        appState.freqMin = Double(clamp(value, min: 20, max: 20000))
                    }
                    print("🎛️ OSC: Set freqMin to \(appState.freqMin)")
                }

            case .freqMax:
                if let value = self.extractFloat(from: arguments) {
                    // Accept either 0-1 normalized or direct Hz value
                    if value <= 1.0 {
                        appState.freqMax = mapToFrequency(value)
                    } else {
                        appState.freqMax = Double(clamp(value, min: 20, max: 20000))
                    }
                    print("🎛️ OSC: Set freqMax to \(appState.freqMax)")
                }

            case .monochrome:
                if let value = self.extractBool(from: arguments) {
                    appState.isMonochrome = value
                } else if let value = self.extractFloat(from: arguments) {
                    appState.isMonochrome = value > 0.5
                } else if let value = self.extractInt(from: arguments) {
                    appState.isMonochrome = value > 0
                }
                print("🎛️ OSC: Set isMonochrome to \(appState.isMonochrome)")

            case .reset:
                appState.reset()
                print("🎛️ OSC: Reset triggered")
            }
        }
    }

    // MARK: - Helper Functions

    private func extractFloat(from arguments: [Any]) -> Float? {
        if let value = arguments.first as? Float {
            return value
        }
        if let value = arguments.first as? Double {
            return Float(value)
        }
        if let value = arguments.first as? Int32 {
            return Float(value)
        }
        if let value = arguments.first as? Int {
            return Float(value)
        }
        return nil
    }

    private func extractInt(from arguments: [Any]) -> Int32? {
        if let value = arguments.first as? Int32 {
            return value
        }
        if let value = arguments.first as? Int {
            return Int32(value)
        }
        if let value = arguments.first as? Float {
            return Int32(value)
        }
        return nil
    }

    private func extractBool(from arguments: [Any]) -> Bool? {
        if let value = arguments.first as? Bool {
            return value
        }
        return nil
    }
}

// MARK: - Utility Functions

private func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
    return Swift.min(Swift.max(value, min), max)
}

private func mapToFrequency(_ normalized: Float) -> Double {
    // Logarithmic mapping for perceptually linear frequency control
    let minLog = log10(20.0)
    let maxLog = log10(20000.0)
    return pow(10, minLog + Double(normalized) * (maxLog - minLog))
}
