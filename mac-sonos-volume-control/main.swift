import Cocoa
import ApplicationServices
import CoreGraphics
import MediaKeyTap
import AppKit

class OSDUtils: NSObject {
    enum Command: Int64 {
        case audioSpeakerVolume = 1
        case audioMuteScreenBlank = 3
    }
    
    enum OSDImage: Int64 {
        case brightness = 1
        case audioSpeaker = 3
        case audioSpeakerMuted = 4
        case contrast = 0
    }

    static func getOSDImageByCommand(command: Command, value: Float = 1) -> OSDImage {
        var osdImage: OSDImage
        switch command {
        case .audioSpeakerVolume:
            osdImage = value > 0 ? .audioSpeaker : .audioSpeakerMuted
        case .audioMuteScreenBlank:
            osdImage = .audioSpeakerMuted
        }
        return osdImage
    }

    static func showOsd(displayID: CGDirectDisplayID, command: Command, value: Float, maxValue: Float = 1, roundChiclet: Bool = false, lock: Bool = false) {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
            return
        }
        let osdImage = self.getOSDImageByCommand(command: command, value: value)
        let filledChiclets: Int
        let totalChiclets: Int
        if roundChiclet {
            let osdChiclet = OSDUtils.chiclet(fromValue: value, maxValue: maxValue)
            filledChiclets = Int(round(osdChiclet))
            totalChiclets = 16
        } else {
            filledChiclets = Int(value * 100)
            totalChiclets = Int(maxValue * 100)
        }
        manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000, filledChiclets: UInt32(filledChiclets), totalChiclets: UInt32(totalChiclets), locked: lock)
    }

    static func showOsdVolumeDisabled(displayID: CGDirectDisplayID) {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
            return
        }
        manager.showImage(22, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
    }

    static func showOsdMuteDisabled(displayID: CGDirectDisplayID) {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
            return
        }
        manager.showImage(21, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
    }

    static func popEmptyOsd(displayID: CGDirectDisplayID, command: Command) {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
            return
        }
        let osdImage = self.getOSDImageByCommand(command: command)
        manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 0)
    }

    static let chicletCount: Float = 16

    static func chiclet(fromValue value: Float, maxValue: Float, half: Bool = false) -> Float {
        (value * self.chicletCount * (half ? 2 : 1)) / maxValue
    }

    static func value(fromChiclet chiclet: Float, maxValue: Float, half: Bool = false) -> Float {
        (chiclet * maxValue) / (self.chicletCount * (half ? 2 : 1))
    }

    static func getDistance(fromNearestChiclet chiclet: Float) -> Float {
        abs(chiclet.rounded(.towardZero) - chiclet)
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
    print("Accessibility permissions granted.")

    class MediaKeyTapDelegateImpl: MediaKeyTapDelegate {
        var sonosClient: SonosModel? = nil

        func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
            if (event?.keyPressed == false && sonosClient != nil) {
                //print("Media key event received: \(mediaKey) \(String(describing: event)) \(String(describing: modifiers))")
                
                switch mediaKey {
                case .volumeUp:
                    sonosClient!.sendKeypressToSonos(keypress: RemoteKey.KEY_VOLUMEUP)
                    let currentVolume = sonosClient!.currentVolume
                    print("Current volume up: \(currentVolume)")
                    OSDUtils.showOsd(displayID: displayID, command: .audioSpeakerVolume, value: normalize(currentVolume))
                    
                case .volumeDown:
                    sonosClient!.sendKeypressToSonos(keypress: RemoteKey.KEY_VOLUMEDOWN)
                    let currentVolume = sonosClient!.currentVolume
                    print("Current volume down: \(currentVolume)")
                    OSDUtils.showOsd(displayID: displayID, command: .audioSpeakerVolume, value: normalize(currentVolume))
                    
                case .mute:
                    sonosClient!.sendKeypressToSonos(keypress: RemoteKey.KEY_VOLUMEMUTE)
                    let currentVolume = sonosClient!.currentVolume
                    print("Current volume mute: \(currentVolume)")
                    // TODO restore this volume after we unmute.
                    OSDUtils.showOsd(displayID: displayID, command: .audioMuteScreenBlank, value: 0)
                default:
                    print("Unhandled media key: \(mediaKey)")
                    break
                }
            }
        }
    }
    
    print("Starting media key monitoring...")
    let delegate = MediaKeyTapDelegateImpl()
    let mediaKeyTap = MediaKeyTap(delegate: delegate, on: .keyDownAndUp)
    
    print("Bind media keys")
    mediaKeyTap.start()
    
    print("Connecting to sonos device");
    let sonosClient = SonosModel()
    sonosClient.connect() {
        print("Connected loading volume");
        sonosClient.sendKeypressToSonos(keypress: RemoteKey.KEY_LOADVOLUME)
        delegate.sonosClient = sonosClient
    }
    
    print("Entering run loop...")
    RunLoop.main.run()
} else {
    print("Accessibility permissions not granted. Exiting...")
}


