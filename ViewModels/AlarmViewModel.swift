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
        let difference = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: time)
        // make sure no date in the past is used, but rather the next time the selected time occurs
        if let diffDays = difference.day, let diffHours = difference.hour, let diffMins = difference.minute {
            if diffHours < 0 || diffMins < 0 {
                // selected time is in the past -> add one day
                if let newTime = Calendar.current.date(byAdding: .day, value: 1, to: time) {
                    alarm = alarm.updateTime(newTime: newTime)
                }
            } else {
                // selected date is in the future, but selected time still occurs on the same day
                if let newTime = Calendar.current.date(byAdding: .day, value: -diffDays, to: time) {
                    alarm = alarm.updateTime(newTime: newTime)
                }
            }
        }
    }
    
    func saveAlarm() {
        if let encodedAlarm = try? JSONEncoder().encode(alarm) {
            UserDefaults.standard.set(encodedAlarm, forKey: alarmDataKey)
        }
        let (hour, minute) = alarm.getHourAndMinuteFromAlarm()
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // set notifications for every day at the given alarm time
        NotificationManager.instance.scheduleCalendarBasedNotification(id: alarm.id, hour: hour, minute: minute)
    }
}
