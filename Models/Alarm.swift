import Foundation

// Immutable struct to prevent unintended modification of app data
// Updates can only be performed through update functions
struct Alarm : Identifiable, Codable {
    let id: String
    let isActive: Bool
    let isScanned: Bool
    let isTriggered: Bool
    let salivaId : Int
    let time : Date
    
    init(id: String, isActive: Bool, isScanned: Bool, isTriggered: Bool, salivaId: Int, time: Date = Date()) {
        self.id = id
        self.isActive = isActive
        self.isScanned = isScanned
        self.isTriggered = isTriggered
        self.salivaId = salivaId
        self.time = time
    }
    
    func updateTime(newTime: Date) -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: isScanned, isTriggered: isTriggered, salivaId: salivaId, time: newTime)
    }
    
    func toggleIsActive() -> Alarm {
        return Alarm(id: id, isActive: !isActive, isScanned: false, isTriggered: false, salivaId: salivaId, time: time)
    }
    
    func setTriggered() -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: isScanned, isTriggered: isTriggered, salivaId: salivaId)
    }
    
    func setScanned() -> Alarm {
        return Alarm(id: id, isActive: false, isScanned: true, isTriggered: isTriggered, salivaId: salivaId)
    }
    
    func getCurrentAlarmTimePlusInterval(numMinutes: Int) -> Date? {
        let nextTime = Calendar.current.date(byAdding: .minute, value: numMinutes, to: time)
        return nextTime
    }
}
