//
//  AudioUtils.swift
//  mac-sonos-volume-control
//
//  Created by Jonathan Beaudoin on 2024-07-10.
//
import CoreAudio

func getDefaultOutputDeviceName() -> String? {
    var defaultOutputDeviceID = AudioDeviceID(0)
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
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
        &propertySize,
        &defaultOutputDeviceID
    )

    guard status == noErr else {
        print("Error getting default output device ID: \(status)")
        return nil
    }

    var deviceName = "" as CFString
    propertySize = UInt32(MemoryLayout<CFString>.size)
    address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let nameStatus = AudioObjectGetPropertyData(
        defaultOutputDeviceID,
        &address,
        0,
        nil,
        &propertySize,
        &deviceName
    )

    guard nameStatus == noErr else {
        print("Error getting device name: \(nameStatus)")
        return nil
    }

    return deviceName as String
}
