import Foundation

// Immutable struct to prevent unintended modification of app data
// Updates can only be performed through update functions
struct Alarm : Identifiable, Codable, Hashable {
    let id: Int
    let isActive: Bool
    let isScanned: Bool
    let isTriggered: Bool
    let time : Date
    
    init(id: Int, isActive: Bool, isScanned: Bool, isTriggered: Bool, time: Date = getDateTomorrowMorning()) {
        self.id = id
        self.isActive = isActive
        self.isScanned = isScanned
        self.isTriggered = isTriggered
        self.time = time
    }
    
    init(id: Int, isActive: Bool, time: Date) {
        self.id = id
        self.isActive = isActive
        self.time = time
        self.isScanned = false
        self.isTriggered = false
    }
    
    var description: String {
        return "Alarm ID: \(id), time: \(getHourMinFormattedString(time: time)), isActive: \(isActive), isTriggered: \(isTriggered), isScanned: \(isScanned)"
    }
    
    func updateTime(newTime: Date) -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: isScanned, isTriggered: isTriggered, time: newTime)
    }
    
    func setIsActive(isActive: Bool) -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: isScanned, isTriggered: isTriggered, time: time)
    }
    
    func setTriggered() -> Alarm {
        return Alarm(id: id, isActive: isActive, isScanned: isScanned, isTriggered: true, time: time)
    }
    
    func setScanned() -> Alarm {
        return Alarm(id: id, isActive: false, isScanned: true, isTriggered: isTriggered, time: time)
    }
    
    func getCurrentAlarmTimePlusInterval(numMinutes: Int) -> Date? {
        let nextTime = Calendar.current.date(byAdding: .minute, value: numMinutes, to: time)
        return nextTime
    }
    
    func getSalivaId(startSample: String) -> Int {
        if let startIndex = Int(startSample.dropFirst())
        {
            return id + startIndex
        }
        return id
    }
}
