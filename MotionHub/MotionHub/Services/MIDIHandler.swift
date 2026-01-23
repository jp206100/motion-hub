//
//  MIDIHandler.swift
//  Motion Hub
//
//  MIDI handling for Push 2 control
//

import Foundation
import CoreMIDI
import Combine

class MIDIHandler: ObservableObject {
    // MARK: - Published Properties
    @Published var availableDevices: [MIDIDeviceInfo] = []
    @Published var selectedDevice: MIDIDeviceInfo?

    // MARK: - MIDI Client
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0

    // MARK: - State Reference
    weak var appState: AppState?

    // MARK: - CC Mappings
    enum ControlChange: UInt8 {
        case intensity = 71      // CC 71
        case glitchAmount = 72   // CC 72
        case speed = 73          // CC 73
        case colorShift = 74     // CC 74
        case freqMin = 75        // CC 75
        case freqMax = 76        // CC 76
        case monochrome = 77     // CC 77 (value > 64 = on)
        case reset = 78          // CC 78 (any value triggers)
    }

    init() {
        setupMIDI()
        loadAvailableDevices()
    }

    deinit {
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    // MARK: - Setup

    private func setupMIDI() {
        var client: MIDIClientRef = 0
        let clientName = "Motion Hub" as CFString

        var status = MIDIClientCreateWithBlock(clientName, &client) { [weak self] notification in
            self?.handleMIDINotification(notification)
        }

        guard status == noErr else {
            print("Error creating MIDI client: \(status)")
            return
        }

        midiClient = client

        // Create input port
        var port: MIDIPortRef = 0
        let portName = "Motion Hub Input" as CFString

        status = MIDIInputPortCreateWithProtocol(
            client,
            portName,
            ._1_0,
            &port
        ) { [weak self] eventList, _ in
            self?.handleMIDIEventList(eventList)
        }

        guard status == noErr else {
            print("Error creating input port: \(status)")
            return
        }

        inputPort = port
    }

    private func loadAvailableDevices() {
        var devices: [MIDIDeviceInfo] = []
        let sourceCount = MIDIGetNumberOfSources()

        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let deviceInfo = getDeviceInfo(for: source) {
                devices.append(deviceInfo)
            }
        }

        DispatchQueue.main.async {
            self.availableDevices = devices

            // Auto-select Push 2 if available
            if let push2 = devices.first(where: { $0.name.lowercased().contains("push") }) {
                self.selectDevice(push2)
            }
        }
    }

    private func getDeviceInfo(for endpoint: MIDIEndpointRef) -> MIDIDeviceInfo? {
        var name: Unmanaged<CFString>?
        var status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)

        guard status == noErr, let deviceName = name?.takeRetainedValue() as String? else {
            return nil
        }

        var uniqueID: Int32 = 0
        status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)

        return MIDIDeviceInfo(
            id: endpoint,
            name: deviceName,
            uniqueID: uniqueID
        )
    }

    // MARK: - MIDI Event Handling

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        // Handle device added/removed notifications
        loadAvailableDevices()
    }

    private func handleMIDIEventList(_ eventList: UnsafePointer<MIDIEventList>) {
        let packets = MIDIEventListGenerator(eventList)

        for packet in packets {
            if packet.count >= 3 {
                let status = packet[0]
                let data1 = packet[1]
                let data2 = packet[2]

                // Check if it's a CC message (0xB0-0xBF)
                if (status & 0xF0) == 0xB0 {
                    handleControlChange(cc: data1, value: data2)
                }
            }
        }
    }

    private func handleControlChange(cc: UInt8, value: UInt8) {
        guard let controlChange = ControlChange(rawValue: cc) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let appState = self.appState else { return }

            switch controlChange {
            case .intensity:
                appState.intensity = Double(value) / 127.0

            case .glitchAmount:
                appState.glitchAmount = Double(value) / 127.0

            case .speed:
                // Map 0-127 to 1-4
                let step = Int(value) / 32
                appState.speed = min(4, max(1, step + 1))

            case .colorShift:
                appState.colorShift = Double(value) / 127.0

            case .freqMin:
                appState.freqMin = self.mapToFrequency(value)

            case .freqMax:
                appState.freqMax = self.mapToFrequency(value)

            case .monochrome:
                appState.isMonochrome = value > 64

            case .reset:
                appState.reset()
            }
        }
    }

    private func mapToFrequency(_ midiValue: UInt8) -> Double {
        // Logarithmic mapping for perceptually linear frequency control
        let normalized = Double(midiValue) / 127.0
        let minLog = log10(20.0)
        let maxLog = log10(20000.0)
        return pow(10, minLog + normalized * (maxLog - minLog))
    }

    // MARK: - Public Methods

    func selectDevice(_ device: MIDIDeviceInfo) {
        // Disconnect from previous device if any
        if let currentDevice = selectedDevice {
            MIDIPortDisconnectSource(inputPort, currentDevice.id)
        }

        // Connect to new device
        let status = MIDIPortConnectSource(inputPort, device.id, nil)

        if status == noErr {
            DispatchQueue.main.async {
                self.selectedDevice = device
            }
        } else {
            print("Error connecting to MIDI device: \(status)")
        }
    }
}

// MARK: - MIDI Device Info
struct MIDIDeviceInfo: Identifiable, Hashable {
    let id: MIDIEndpointRef
    let name: String
    let uniqueID: Int32
}

// MARK: - MIDI Event List Generator
struct MIDIEventListGenerator: Sequence, IteratorProtocol {
    private var currentPacket: UnsafePointer<MIDIEventPacket>?
    private var remainingPackets: UInt32

    init(_ eventList: UnsafePointer<MIDIEventList>) {
        currentPacket = withUnsafePointer(to: eventList.pointee.packet) { $0 }
        remainingPackets = eventList.pointee.numPackets
    }

    mutating func next() -> [UInt8]? {
        guard remainingPackets > 0, let packet = currentPacket else {
            return nil
        }

        remainingPackets -= 1

        // Convert packet words to bytes
        var bytes: [UInt8] = []
        let wordCount = Int(packet.pointee.wordCount)

        withUnsafeBytes(of: packet.pointee.words) { buffer in
            let uint32Pointer = buffer.bindMemory(to: UInt32.self)
            for i in 0..<wordCount {
                let word = uint32Pointer[i]
                bytes.append(UInt8(word & 0xFF))
                bytes.append(UInt8((word >> 8) & 0xFF))
                bytes.append(UInt8((word >> 16) & 0xFF))
                bytes.append(UInt8((word >> 24) & 0xFF))
            }
        }

        // Move to next packet
        if let nextPacket = MIDIEventPacketNext(packet) {
            currentPacket = nextPacket
        } else {
            currentPacket = nil
        }

        return bytes
    }
}
