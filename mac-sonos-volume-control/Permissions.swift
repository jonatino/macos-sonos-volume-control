//
//  Permissions.swift
//  mac-sonos-volume-control
//
//  Created by Jonathan Beaudoin on 2024-07-10.
//
import Network
import Cocoa
import ApplicationServices

func requestLocalNetworkAccessOrWait() {
    var flagged = false
    var accessGranted = false
    
    while !accessGranted {
        // TODO find a way to automate this? Dont hardcode ip
        ping(host: "172.27.0.1") { success in
            accessGranted = success
            if !success {
                if !flagged {
                    print("Please enable local network permissions for this application.")
                    print("Go to System Preferences -> Privacy & Security -> Local Network and add this application to the list.")
                    flagged = true
                }
            }
        }
        
        if !accessGranted {
            sleep(3)
        }
    }
}

func requestAccessibilityPermissionsOrWait() {
    var flagged = false
    while true {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        if accessibilityEnabled {
            break
        } else {
            if !flagged {
                print("Please enable accessibility permissions for this application.")
                print("Go to System Preferences -> Privacy & Security -> Accessibility and add this application to the list.")
                flagged = true
            }
            
            sleep(3)
        }
    }
}

private func ping(host: String, completion: @escaping (Bool) -> Void) {
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
