import CoreGraphics
import MediaKeyTap
import AppKit
import Foundation

import CoreAudio
import AudioToolbox

// CONFIGURE THESE

// This is the name of the Sonos device that you want to control the volume of
let SONOS_DEVICE_NAME: String = "Bedroom"

// This is the ip address of any device on your local network. Used to test if permissions is granted
let GATEWAY_LAN_PING_IP: String = "172.27.0.1"

// This is the name of the HDMI audio output device in macOS
let HDMI_SOUND_OUTPUT_DEVICE_NAME: String = "LG TV SSCR2"

// END OF CONFIGURE

func normalize(_ value: Int) -> Float {
    return min(max(Float(value) / 100.0, 0.0), 1.0)
}

let displayID: CGDirectDisplayID? = getPrimaryDisplayID()
if displayID == nil {
    fatalError("Could not find primary display")
}

print("Primary display id:", displayID!)

print("Requesting local network access. Waiting until access granted before continuing.")
print("\tTo connect and send commands to your Sonos device.")
requestAccessibilityPermissionsOrWait()

print("Requesting accessibility access. Waiting until access granted before continuing.")
print("\tTo know when the volume down, volume up, or mute buttons are pressed.")
requestLocalNetworkAccessOrWait()

print("Starting media key monitoring...")
let delegate = MediaKeyTapDelegateImpl()
let mediaKeyTap = MediaKeyTap(delegate: delegate, on: .keyUp, for: [MediaKey.volumeUp, MediaKey.volumeDown, MediaKey.mute])

print("Binding media keys")
mediaKeyTap.start()

print("Connecting to sonos device");
let sonosClient = SonosModel()
sonosClient.connect(deviceName: SONOS_DEVICE_NAME) {
    print("Connected. Loading current volume");
    sonosClient.setRelativeVolume(adjustment: 0)
    delegate.sonosClient = sonosClient
}

print("Entering run loop...")
RunLoop.main.run()

class MediaKeyTapDelegateImpl: MediaKeyTapDelegate {
    var sonosClient: SonosModel? = nil
    var volumeBeforeMute: Int = 0

    func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
        if (sonosClient != nil) {
            let outputDeviceName = getDefaultOutputDeviceName()
            if outputDeviceName != HDMI_SOUND_OUTPUT_DEVICE_NAME {
                print("Sound output device changed to:", outputDeviceName as Any)
                
                print("Disable media key hook")
                mediaKeyTap.stop()
                
                print("Waiting until device \(HDMI_SOUND_OUTPUT_DEVICE_NAME) is plugged in or activated again.")
                while true {
                    let outputDeviceName = getDefaultOutputDeviceName()
                    if outputDeviceName != HDMI_SOUND_OUTPUT_DEVICE_NAME {
                        sleep(3)
                    } else {
                        print("Sonos device \(outputDeviceName!) is active.")
                        print("Rebinding media keys")
                        mediaKeyTap.start()
                        return
                    }
                }
            }
            //print("Media key event received: \(mediaKey) \(String(describing: event)) \(String(describing: modifiers))")

            // This means we're muted!
            if volumeBeforeMute != 0 {
                print("Unmuting. Restoring volume: \(volumeBeforeMute)")
                sonosClient!.setRelativeVolume(adjustment: volumeBeforeMute)
                OSDUtils.showOsd(displayID: displayID!, command: .audioSpeakerVolume, value: normalize(volumeBeforeMute))
                volumeBeforeMute = 0
            } else {
                var adjustment: Int!
                var command: OSDUtils.Command = .audioSpeakerVolume
                
                let currentVolume = sonosClient!.currentVolume
                
                if mediaKey == .volumeUp {
                    print("Volume up: \(currentVolume)")
                    adjustment = 2
                } else if mediaKey == .volumeDown {
                    print("Volume down: \(currentVolume)")
                    adjustment = -2
                } else if mediaKey == .mute {
                    print("Muting. Saving current volume: \(currentVolume)")
                    volumeBeforeMute = currentVolume
                    adjustment = -100
                    command = .audioMuteScreenBlank
                }
                
                sonosClient!.setRelativeVolume(adjustment: adjustment)
                OSDUtils.showOsd(displayID: displayID!, command: command, value: (volumeBeforeMute != 0) ? 0 : normalize(currentVolume))
            }
        }
    }
}

private func getPrimaryDisplayID() -> CGDirectDisplayID? {
    var displayCount: UInt32 = 0
    var result = CGGetActiveDisplayList(0, nil, &displayCount)
    if result != CGError.success {
        print("Error getting active display list: \(result)")
        return nil
    }

    let allocated = Int(displayCount)
    let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
    result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)

    if result != CGError.success {
        print("Error getting active display list: \(result)")
        activeDisplays.deallocate()
        return nil
    }

    let primaryDisplayID = activeDisplays[0]
    activeDisplays.deallocate()
    return primaryDisplayID
}
