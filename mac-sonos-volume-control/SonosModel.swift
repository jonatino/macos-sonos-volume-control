//
//  SonosModel.swift
//  TestSocket
//
//  Created by Denis Blondeau on 2023-12-20.
//

import AppKit
import Combine
import Foundation
import SonosAPI

@Observable final class SonosModel {
    
    private(set) var currentVolume = 0
    
    private var coordinatorURL: URL?
    private var subscriptions: Set<AnyCancellable> = []
    private var temporarySubscription: AnyCancellable?
    
    func connect(deviceName: String, callback: @escaping () -> Void) {
        if coordinatorURL != nil {
            fatalError("Coordinator URL already set. Create a new SonosClient to connect to another device.")
        }
        
        // Clean-up when app terminates.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            self.temporarySubscription?.cancel()
            self.subscriptions.removeAll()
        }

        self.getDevices(coordinatorName: deviceName) {
            callback()
        }
    }
    
    /// Retrieve Sonos devices on the local network.
    private func getDevices(coordinatorName: String, callback: @escaping () -> Void) {
        let ssdp = SSDPSession()
        var sonosDevices = [SonosDevice]()
        
        temporarySubscription = ssdp.onDeviceFound.sink { completion in
            self.temporarySubscription?.cancel()
            
            switch completion {
            case .failure(let error):
                fatalError(error.description)
                
            case .finished:
                self.retrieveHouseholdCoordinators(coordinatorName: coordinatorName, for: sonosDevices) {
                    callback()
                }
            }
        } receiveValue: { record in
            sonosDevices.append(record)
        }
        
        do {
            try ssdp.run()
        } catch {
            fatalError("Cannot run SSDP session: \(error.localizedDescription)")
        }
    }
    
    /// Retrieve zone/household groups with their coordinator id.
    /// - Parameter sonosDevices: Sonos devices.
    private func retrieveHouseholdCoordinators(coordinatorName: String, for sonosDevices: [SonosDevice], callback: @escaping () -> Void) {
        guard sonosDevices.count > 0 else {
            print("Sonos devices was empty")
            return
        }
        guard let url = sonosDevices[0].hostURL else { 
            print("Host url was empty", sonosDevices)
            return
        }
        
        var groups = [SonosGroup]()
        
        let session = SOAPActionSession(service: .zoneGroupTopology(action: .getZoneGroupState, url: url))
        
        temporarySubscription = session.onDataReceived.sink { completion in
            self.temporarySubscription?.cancel()
            
            switch completion {
            case .finished:
                break
                
            case .failure(let error):
                fatalError(error.description)
            }
            
        } receiveValue: { json in
            parseJSONToObject(json: json) { (groupData: ZoneGroupTopology?) in
                guard let groupData else { return }
                
                for zoneGroup in groupData.zoneGroupState.zoneGroups.zoneGroup {
                    for zoneGroupMember in zoneGroup.zoneGroupMember {
                        
                        if zoneGroupMember.uuid == zoneGroup.coordinator {
                            var name: String
                            if zoneGroup.zoneGroupMember.count == 1 {
                                name = zoneGroupMember.zoneName
                            } else {
                                name = "\(zoneGroupMember.zoneName) + \(zoneGroup.zoneGroupMember.count - 1)"
                            }
                            
                            let group = SonosGroup(id: zoneGroupMember.uuid, coordinatorURL: zoneGroupMember.hostURL!, name: name)
                            groups.append(group)
                        }
                    }
                }
                
                groups.sort { $0.name < $1.name }
                let group = groups.first (where: { $0.name == coordinatorName })
                if let group {
                    self.coordinatorURL = group.coordinatorURL
                    callback()
                } else {
                    fatalError("Sonos Group \(coordinatorName) cannot be found.")
                }
            }
        }
        session.run()
    }
    
    func setRelativeVolume(adjustment: Int)   {
        guard let coordinatorURL else { fatalError("Coordinator URL is not set.") }
            
        let session = SOAPActionSession(service: .groupRenderingControl(action: .setRelativeGroupVolume, url: coordinatorURL, adjustment: adjustment))
        
        // TODO make this async and dont exit the method until new volume is set
        temporarySubscription = session.onDataReceived.sink { completion in
            self.temporarySubscription?.cancel()
            switch completion {
            case .finished:
                break
            case .failure(let error):
                print("**** Error in \(#function) : \(error.description) *****")
            }
        } receiveValue: { jsonData in
            parseJSONToObject(json: jsonData) { (newVolume:  NewVolume?) in
                if let newVolume {
                    self.currentVolume = newVolume.volume
                }
            }
        }
        session.run()
    }
    
}
