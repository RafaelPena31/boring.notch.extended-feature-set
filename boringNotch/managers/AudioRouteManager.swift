//
//  AudioRouteManager.swift
//  boringNotch
//

import Combine
import CoreAudio
import Foundation

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let transportType: UInt32

    var iconName: String {
        let normalized = name.lowercased()

        if normalized.contains("airpods max") { return "airpodsmax" }
        if normalized.contains("airpods pro") { return "airpodspro" }
        if normalized.contains("airpods") { return "airpods" }
        if normalized.contains("macbook") { return "laptopcomputer" }
        if normalized.contains("homepod") { return "homepod" }
        if normalized.contains("headphone") || normalized.contains("headset") || normalized.contains("beats") {
            return "headphones"
        }
        if normalized.contains("display") || normalized.contains("monitor") { return "display" }

        switch transportType {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return normalized.contains("speaker") ? "hifispeaker" : "headphones"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeHDMI:
            return "tv"
        case kAudioDeviceTransportTypeUSB:
            return "hifispeaker"
        case kAudioDeviceTransportTypeBuiltIn:
            return "laptopcomputer"
        default:
            return "speaker.wave.2"
        }
    }
}

@MainActor
final class AudioRouteManager: ObservableObject {
    static let shared = AudioRouteManager()

    @Published private(set) var devices: [AudioOutputDevice] = []
    @Published private(set) var activeDeviceID: AudioDeviceID = 0

    var activeDevice: AudioOutputDevice? {
        devices.first { $0.id == activeDeviceID }
    }

    private let queue = DispatchQueue(label: "boringNotch.AudioRouteManager")

    private init() {}

    func refreshDevices() {
        queue.async { [weak self] in
            let defaultID = Self.fetchDefaultOutputDevice()
            let found = Self.fetchOutputDeviceIDs().compactMap(Self.makeDevice)
            let sorted = found.sorted { lhs, rhs in
                if lhs.id == rhs.id { return false }
                if lhs.id == defaultID { return true }
                if rhs.id == defaultID { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            Task { @MainActor in
                self?.activeDeviceID = defaultID
                self?.devices = sorted
            }
        }
    }

    func select(_ device: AudioOutputDevice) {
        queue.async { [weak self] in
            guard Self.setDefaultOutputDevice(device.id) else { return }

            Task { @MainActor in
                self?.activeDeviceID = device.id
                self?.refreshDevices()
            }
        }
    }

    nonisolated private static func fetchDefaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : 0
    }

    @discardableResult
    nonisolated private static func setDefaultOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        let selectors = [
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultSystemOutputDevice,
        ]
        var changedDefaultOutput = false

        for selector in selectors {
            var target = deviceID
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &target
            )
            if selector == kAudioHardwarePropertyDefaultOutputDevice {
                changedDefaultOutput = status == noErr
            }
        }

        return changedDefaultOutput
    }

    nonisolated private static func fetchOutputDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr else { return [] }

        var ids = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &ids
        ) == noErr else { return [] }

        return ids.filter(hasOutputStreams)
    }

    nonisolated private static func hasOutputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return false
        }
        return size > 0
    }

    nonisolated private static func makeDevice(_ deviceID: AudioDeviceID) -> AudioOutputDevice? {
        guard let name = stringProperty(deviceID, kAudioObjectPropertyName), !name.isEmpty else {
            return nil
        }
        return AudioOutputDevice(
            id: deviceID,
            name: name,
            transportType: transportType(deviceID)
        )
    }

    nonisolated private static func stringProperty(
        _ deviceID: AudioDeviceID,
        _ selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString?
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        return value as String?
    }

    nonisolated private static func transportType(_ deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &value
        ) == noErr else { return 0 }
        return value
    }
}
