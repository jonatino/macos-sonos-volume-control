import Cocoa
import ApplicationServices
import CoreGraphics
import MediaKeyTap
import AppKit
import Foundation
import Network;

func ping(host: String, completion: @escaping (Bool) -> Void) {
    let hostEndpoint = NWEndpoint.Host(host)
    let port: NWEndpoint.Port = 80 // HTTP port, you can choose any other port if needed

    let params = NWParameters.udp
    params.allowLocalEndpointReuse = true
    params.includePeerToPeer = true

    let connection = NWConnection(host: hostEndpoint, port: port, using: params)
    
    connection.stateUpdateHandler = { newState in
        switch newState {
        case .ready:
            print("Ping successful!")
            completion(true)
            connection.cancel()
        case .failed(let error):
            print("Ping failed with error: \(error)")
            completion(false)
            connection.cancel()
        default:
            break
        }
    }

    connection.start(queue: .global())
}

// Usage
ping(host: "172.27.0.1") { success in
    if success {
        print("Local network access is available.")
    } else {
        print("Local network access is not available.")
    }
}

func getPrimaryDisplayID() -> CGDirectDisplayID? {
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

func requestAccessibilityPermissions() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
    let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
    if !accessibilityEnabled {
        print("Please enable accessibility permissions for this application.")
        print("Go to System Preferences -> Security & Privacy -> Privacy -> Accessibility and add this application to the list.")
    } else {
        print("Accessibility permissions granted.")
    }
    return accessibilityEnabled
}

func normalize(_ value: Int) -> Float {
    return min(max(Float(value) / 100.0, 0.0), 1.0)
}

let displayID = getPrimaryDisplayID() ?? 0

print("Requesting accessibility permissions...")
if requestAccessibilityPermissions() {
    class MediaKeyTapDelegateImpl: MediaKeyTapDelegate {
        var sonosClient: SonosModel? = nil
        var volumeBeforeMute: Int = 0

        func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
            if (sonosClient != nil) {
                print("Media key event received: \(mediaKey) \(String(describing: event)) \(String(describing: modifiers))")

                // This means we're muted!
                if volumeBeforeMute != 0 {
                    print("Unmuting. Restoring volume: \(volumeBeforeMute)")
                    sonosClient!.setRelativeVolume(adjustment: volumeBeforeMute)
                    OSDUtils.showOsd(displayID: displayID, command: .audioSpeakerVolume, value: normalize(volumeBeforeMute))
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
                    OSDUtils.showOsd(displayID: displayID, command: command, value: (volumeBeforeMute != 0) ? 0 : normalize(currentVolume))
                }
            }
        }
    }
    
    print("Starting media key monitoring...")
    let delegate = MediaKeyTapDelegateImpl()
    let mediaKeyTap = MediaKeyTap(delegate: delegate, on: .keyUp, for: [MediaKey.volumeUp, MediaKey.volumeDown, MediaKey.mute])
    
    print("Binding media keys")
    mediaKeyTap.start()
    
    print("Connecting to sonos device");
    let sonosClient = SonosModel()
    sonosClient.connect(deviceName: "Bedroom") {
        print("Connected. Loading current volume");
        sonosClient.setRelativeVolume(adjustment: 0)
        delegate.sonosClient = sonosClient
    }
    
    print("Entering run loop...")
    RunLoop.main.run()
} else {
    print("Accessibility permissions not granted. Exiting...")
}


