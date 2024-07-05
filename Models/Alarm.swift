//
//  Alarm.swift
//  CARWatch
//
//  Created by Admin on 02.07.24.
//

import Foundation

// Immutable struct to prevent unintended modification of app data
// Updates can only be performed through update functions
struct Alarm : Identifiable, Codable {
    let id: String
    let isActive: Bool
    let isScanned: Bool
    let salivaId : Int
    let time : Date
    
    init(id: String, isActive: Bool, isScanned: Bool, salivaId: Int, time: Date = Date()) {
        self.id = id
        self.isActive = isActive
        self.isScanned = isScanned
        self.salivaId = salivaId
        self.time = time
    }
    
    func updateTime(newTime: Date) -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: isScanned, salivaId: salivaId, time: newTime)
    }
    
    func toggleIsActive() -> Alarm {
        return Alarm(id: id, isActive: !isActive, isScanned: isScanned, salivaId: salivaId, time: time)
    }
}
