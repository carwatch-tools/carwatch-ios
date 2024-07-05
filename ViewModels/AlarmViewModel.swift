import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var alarm: Alarm = Alarm(id: "initial", isActive: false, isScanned: false, salivaId: -1) {
        didSet {
            saveAlarm()
        }
    }
    let alarmDataKey = "alarm"
    
    init() {
        getCurrentAlarm()
    }
    
    func getCurrentAlarm() {
        guard
            let alarmData = UserDefaults.standard.data(forKey: alarmDataKey),
            let savedAlarm = try? JSONDecoder().decode(Alarm.self, from: alarmData)
        else { 
            return
        }
        alarm = savedAlarm
    }
    
    func getTimeUntilNextAlarm() -> (Int, Int) {
        let timeInterval = NSInteger(alarm.time.timeIntervalSinceNow)
        let minutes = (timeInterval / 60) % 60
        let hours = (timeInterval / 3600)
        return (hours, minutes)
    }
    
    func toggleCurrentAlarm() {
        alarm = alarm.toggleIsActive()
    }
    
    func updateAlarmTime(time: Date) {
        var newTime: Date
        print("updating alarm time")
        if time.timeIntervalSinceNow.sign == .minus {
            print("sign is minus")
            // if selected date is in the past, select next day
            newTime = time.addingTimeInterval(3600 * 24)
        } else {
            newTime = time
        }
        alarm = alarm.updateTime(newTime: newTime)
    }
    
    func saveAlarm() {
        if let encodedAlarm = try? JSONEncoder().encode(alarm) {
            UserDefaults.standard.set(encodedAlarm, forKey: alarmDataKey)
        }
    }
}
