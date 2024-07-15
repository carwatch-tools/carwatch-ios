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
        return Alarm(id: id, isActive: !isActive, isScanned: isScanned, isTriggered: isTriggered, salivaId: salivaId, time: time)
    }
    
    func setTriggered() -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: isScanned, isTriggered: true, salivaId: salivaId)
    }
    
    func setScanned() -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: true, isTriggered: isTriggered, salivaId: salivaId)
    }
    
    static func getHourAndMinuteFromTime(time: Date) -> (Int, Int, Int) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        let day = calendar.component(.day, from: time)
        return (day, hour, minute)
    }
    
    func getCurrentAlarmTimePlusInterval(numMinutes: Int) -> Date? {
        let nextTime = Calendar.current.date(byAdding: .minute, value: numMinutes, to: time)
        return nextTime
    }
}
