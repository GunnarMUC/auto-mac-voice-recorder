import Foundation
import CoreAudio
import AVFoundation

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

final class AudioDeviceManager {
    static func listInputDevices() -> [AudioDevice] {
        let ids = allDeviceIDs()
        return ids.compactMap { id in
            guard deviceHasInput(id) else { return nil }
            guard let name = deviceName(id) else { return nil }
            guard let uid = deviceUID(id) else { return nil }
            return AudioDevice(id: id, uid: uid, name: name)
        }
    }

    static func currentInputDevice() -> AudioDevice? {
        let id = defaultInputDeviceID()
        guard id != kAudioObjectUnknown else { return nil }
        guard let name = deviceName(id) else { return nil }
        guard let uid = deviceUID(id) else { return nil }
        return AudioDevice(id: id, uid: uid, name: name)
    }

    static func setInputDevice(_ device: AudioDevice, on engine: AVAudioEngine) {
        guard let audioUnit = engine.inputNode.audioUnit else { return }
        var deviceID = device.id
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    // MARK: - Private Core Audio helpers

    private static let sysObject = AudioObjectID(kAudioObjectSystemObject)

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(sysObject, &prop, 0, nil, &dataSize) == noErr else { return [] }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(sysObject, &prop, 0, nil, &dataSize, &devices) == noErr else { return [] }
        return devices
    }

    private static func deviceHasInput(_ id: AudioDeviceID) -> Bool {
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &prop, 0, nil, &dataSize) == noErr,
              dataSize > 0,
              dataSize < 1024 * 1024
        else { return false }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: 8)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &prop, 0, nil, &dataSize, raw) == noErr else { return false }
        let bufList = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return bufList.contains { $0.mNumberChannels > 0 }
    }

    private static func deviceName(_ id: AudioDeviceID) -> String? {
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &prop, 0, nil, &dataSize, &name) == noErr,
              let val = name?.takeUnretainedValue()
        else { return nil }
        return val as String
    }

    private static func deviceUID(_ id: AudioDeviceID) -> String? {
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &prop, 0, nil, &dataSize, &uid) == noErr,
              let val = uid?.takeUnretainedValue()
        else { return nil }
        return val as String
    }

    private static func defaultInputDeviceID() -> AudioDeviceID {
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(sysObject, &prop, 0, nil, &dataSize, &id)
        return id
    }
}
