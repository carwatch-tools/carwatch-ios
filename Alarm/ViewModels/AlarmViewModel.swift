import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var alarm: Alarm = Alarm(id: "initial", isActive: false, isScanned: false, isTriggered: false, salivaId: -1) {
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
        updateAlarmTime(time: alarm.time)
    }
    
    func getTimeUntilNextAlarm() -> (Int, Int) {
        let timeInterval = NSInteger(alarm.time.timeIntervalSinceNow)
        let minutes = (timeInterval / 60) % 60
        let hours = (timeInterval / 3600)
        return (hours, minutes)
    }
    
    func toggleCurrentAlarm() {
        print("toggle alarm")
        alarm = alarm.toggleIsActive()
        updateAlarmTime(time: alarm.time)
    }
    
    func setAlarmTriggered() {
        alarm = alarm.setTriggered()
    }
    
    func setAlarmScanned() {
        alarm = alarm.setScanned()
        // cancel all remaining alarms
        NotificationManager.instance.cancelAllNotifications()
        print("set scanned: \(alarm.isScanned)")
        print("notifications canceled")
        // TODO: schedule subsequent reminders/alarm for next day
    }
    
    func isScanRequired() -> Bool {
        print("is scanned: \(alarm.isScanned)")
        print("is triggered: \(alarm.isTriggered)")
        print("return isReq: \(!alarm.isScanned && alarm.isTriggered)")
        return !alarm.isScanned && alarm.isTriggered
    }
    
    func updateAlarmTime(time: Date) {
        print("update time")
        let difference = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: time)
        print(difference.day!)
        print(difference.hour!)
        print(difference.minute!)
        var newTime = time
        // make sure no date in the past is used, but rather the next time the selected time occurs
        if let diffDays = difference.day, let diffHours = difference.hour, let diffMins = difference.minute {
            // set day to today
            if let time = Calendar.current.date(byAdding: .day, value: -diffDays, to: newTime) {
                newTime = time
                print("new time: \(newTime)")
            }
            if diffHours < 0 || diffMins < 0 {
                // selected time is in the past -> add one more day
                if let time = Calendar.current.date(byAdding: .day, value: 1, to: newTime) {
                    newTime = time
                    print("new time tmrw: \(newTime)")
                }
            }
        }
        alarm = alarm.updateTime(newTime: newTime)
        scheduleAlarmWithBackupNotifications()
        
    }
    
    func saveAlarm() {
        if let encodedAlarm = try? JSONEncoder().encode(alarm) {
            UserDefaults.standard.set(encodedAlarm, forKey: alarmDataKey)
        }
    }
    
    func scheduleAlarmWithBackupNotifications() {
        print("schedule alarm with backup notifications")
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // do not schedule new notifications if alarm toggle is set inactive
        if !alarm.isActive {
            return
        }
        for i in 0..<NotificationConstants.numberOfSubsequentNotifications {
            // calculate notification time
            guard let notificationTime = alarm.getCurrentAlarmTimePlusInterval(numMinutes: i * NotificationConstants.minutesBetweenNotifications) else {
                print("scheduling backup notifications failed at notification \(i)")
                return
            }
            
            let (day, hour, minute) = getHourAndMinuteFromTime(time: notificationTime)
            // set notification for next day at the given alarm time
            NotificationManager.instance.scheduleCalendarBasedNotification(id: "\(alarm.id)_\(i)", day: day, hour: hour, minute: minute)
        }
    }
}
