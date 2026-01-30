//
//  OSCHandler.swift
//  Motion Hub
//
//  OSC (Open Sound Control) server for external control via Max for Live
//

import Foundation
import Network
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
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.motionhub.osc", qos: .userInteractive)

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
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isConnected = true
                        print("🎛️ OSC server listening on port \(self?.port ?? 9000)")
                    case .failed(let error):
                        self?.isConnected = false
                        print("❌ OSC server failed: \(error)")
                    case .cancelled:
                        self?.isConnected = false
                        print("🛑 OSC server stopped")
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: queue)

        } catch {
            print("❌ Failed to create OSC listener: \(error)")
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }

    func stopServer() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    private func restartServer() {
        stopServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startServer()
        }
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        print("🎛️ OSC: New connection from \(connection.endpoint)")

        connection.stateUpdateHandler = { [weak self] state in
            print("🎛️ OSC connection state: \(state)")
            if case .ready = state {
                self?.receiveMessage(on: connection)
            }
        }

        connection.start(queue: queue)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            print("🎛️ OSC: receiveMessage callback - data: \(data?.count ?? 0) bytes, error: \(String(describing: error))")

            if let data = data, !data.isEmpty {
                print("🎛️ OSC: Received \(data.count) bytes: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
                self?.parseOSCMessage(data)
            }

            if let error = error {
                print("🎛️ OSC receive error: \(error)")
                return
            }

            // Continue receiving
            self?.receiveMessage(on: connection)
        }
    }

    // MARK: - OSC Parsing

    private func parseOSCMessage(_ data: Data) {
        print("🎛️ OSC: Parsing message of \(data.count) bytes")
        guard data.count >= 4 else {
            print("🎛️ OSC: Message too short")
            return
        }

        var offset = 0

        // Parse address pattern (null-terminated, padded to 4 bytes)
        guard let address = readOSCString(from: data, offset: &offset) else {
            print("🎛️ OSC: Failed to parse address")
            return
        }
        print("🎛️ OSC: Address = '\(address)'")

        // Parse type tag string (starts with ',')
        guard let typeTag = readOSCString(from: data, offset: &offset),
              typeTag.hasPrefix(",") else {
            print("🎛️ OSC: Failed to parse type tag (got: \(readOSCString(from: data, offset: &offset) ?? "nil"))")
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
                    appState.intensity = Double(clamp(value, min: 0, max: 1))
                }

            case .glitchAmount:
                if let value = self.extractFloat(from: arguments) {
                    appState.glitchAmount = Double(clamp(value, min: 0, max: 1))
                }

            case .speed:
                if let value = self.extractFloat(from: arguments) {
                    // Map 0-1 to 1-4, or accept direct 1-4 values
                    if value <= 1.0 {
                        appState.speed = Int(value * 3) + 1
                    } else {
                        appState.speed = Int(clamp(value, min: 1, max: 4))
                    }
                } else if let value = self.extractInt(from: arguments) {
                    appState.speed = Int(clamp(Float(value), min: 1, max: 4))
                }

            case .colorShift:
                if let value = self.extractFloat(from: arguments) {
                    appState.colorShift = Double(clamp(value, min: 0, max: 1))
                }

            case .freqMin:
                if let value = self.extractFloat(from: arguments) {
                    // Accept either 0-1 normalized or direct Hz value
                    if value <= 1.0 {
                        appState.freqMin = mapToFrequency(value)
                    } else {
                        appState.freqMin = Double(clamp(value, min: 20, max: 20000))
                    }
                }

            case .freqMax:
                if let value = self.extractFloat(from: arguments) {
                    // Accept either 0-1 normalized or direct Hz value
                    if value <= 1.0 {
                        appState.freqMax = mapToFrequency(value)
                    } else {
                        appState.freqMax = Double(clamp(value, min: 20, max: 20000))
                    }
                }

            case .monochrome:
                if let value = self.extractBool(from: arguments) {
                    appState.isMonochrome = value
                } else if let value = self.extractFloat(from: arguments) {
                    appState.isMonochrome = value > 0.5
                } else if let value = self.extractInt(from: arguments) {
                    appState.isMonochrome = value > 0
                }

            case .reset:
                appState.reset()
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
