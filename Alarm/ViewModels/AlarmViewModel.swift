import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var timedAlarms: [Alarm] = [Alarm(id: "timed_0", isActive: false, isScanned: false, isTriggered: false, salivaId: -1)] {
        didSet {
            saveTimedAlarms()
        }
    }
    @Published var initialAlarm: Alarm = Alarm(id: "initial", isActive: false, isScanned: false, isTriggered: false, salivaId: -1) {
        didSet {
            saveInitialAlarm()
        }
    }
    
    let initialAlarmDataKey = "alarm"
    let timedAlarmDataKey = "alarmsList"
    
    init() {
        getAlarmData()
    }
    
    func getAlarmData() {
        guard
            let initialAlarmData = UserDefaults.standard.data(forKey: initialAlarmDataKey),
            let savedInitialAlarm = try? JSONDecoder().decode(Alarm.self, from: initialAlarmData)
        else {
            return
        }
        guard
            let timedAlarmData = UserDefaults.standard.data(forKey: timedAlarmDataKey),
            let savedTimedAlarms = try? JSONDecoder().decode([Alarm].self, from: timedAlarmData)
        else {
            return
        }
        initialAlarm = savedInitialAlarm
        updateAlarmTime(time: initialAlarm.time)
        timedAlarms = savedTimedAlarms
    }
    
    func getInitialAlarm() {
        // TODO
    }
    
    func getNextAlarm() {
        // TODO
    }
    
    func getAlarmActiveInfo() -> [Bool] {
        var alarmsActive = [Bool]()
        for alarm in timedAlarms {
            alarmsActive.append(alarm.isActive)
        }
        return alarmsActive
    }
    
    func getTimeUntilNextInitialAlarm() -> (Int, Int) {
        let timeInterval = NSInteger(initialAlarm.time.timeIntervalSinceNow)
        let minutes = (timeInterval / 60) % 60
        let hours = (timeInterval / 3600)
        return (hours, minutes)
    }
    
    func toggleInitialAlarm() {
        initialAlarm = initialAlarm.toggleIsActive()
        updateAlarmTime(time: initialAlarm.time)
    }
    
    func toggleTimedAlarm(index: Int) {
        timedAlarms[index] = timedAlarms[index].toggleIsActive()
        print("toggled: \(timedAlarms[index].isActive)")
    }
    
    func setAlarmTriggered() {
        initialAlarm = initialAlarm.setTriggered()
    }
    
    func setAlarmScanned() {
        initialAlarm = initialAlarm.setScanned()
        // cancel all remaining alarms
        NotificationManager.instance.cancelAllNotifications()
        print("set scanned: \(initialAlarm.isScanned)")
        print("notifications canceled")
        // TODO: schedule subsequent reminders/alarm for next day
    }
    
    func isScanRequired() -> Bool {
        print("is scanned: \(initialAlarm.isScanned)")
        print("is triggered: \(initialAlarm.isTriggered)")
        print("return isReq: \(!initialAlarm.isScanned && initialAlarm.isTriggered)")
        return !initialAlarm.isScanned && initialAlarm.isTriggered
    }
    
    func updateAlarmTime(time: Date) {
        // TODO: only allow this when no alarm is currently ongoing
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
        initialAlarm = initialAlarm.updateTime(newTime: newTime)
        scheduleAlarmWithBackupNotifications()
        updateTimedAlarms()
    }
    
    func updateTimedAlarms() {
        // TODO: access intervals from study configuration
        // TODO: make sure the initial alarm is also included
        var dummyIntervals = [0, 15, 30, 45]
        var updatedTimedAlarms = [Alarm]()
        for (index, interval) in dummyIntervals.enumerated() {
            updatedTimedAlarms.append(Alarm(id: "timed_\(index)", isActive: initialAlarm.isActive, salivaId: index, time: initialAlarm.time.addingTimeInterval(TimeInterval(interval * 60))))
            print("updated alarm time: \(updatedTimedAlarms[index].time)")
        }
        timedAlarms = updatedTimedAlarms
    }
    
    func saveInitialAlarm() {
        if let encodedInitialAlarm = try? JSONEncoder().encode(initialAlarm) {
            UserDefaults.standard.set(encodedInitialAlarm, forKey: initialAlarmDataKey)
        }
    }
    
    func saveTimedAlarms() {
        if let encodedTimedAlarms = try? JSONEncoder().encode(timedAlarms) {
            UserDefaults.standard.set(encodedTimedAlarms, forKey: timedAlarmDataKey)
        }
    }
    
    func scheduleAlarmWithBackupNotifications() {
        print("schedule alarm with backup notifications")
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // do not schedule new notifications if alarm toggle is set inactive
        if !initialAlarm.isActive {
            return
        }
        for i in 0..<NotificationConstants.numberOfSubsequentNotifications {
            // calculate notification time
            guard let notificationTime = initialAlarm.getCurrentAlarmTimePlusInterval(numMinutes: i * NotificationConstants.minutesBetweenNotifications) else {
                print("scheduling backup notifications failed at notification \(i)")
                return
            }
            
            let (day, hour, minute) = getDayHourMinuteFromTime(time: notificationTime)
            // set notification for next day at the given alarm time
            NotificationManager.instance.scheduleCalendarBasedNotification(id: "\(initialAlarm.id)_\(i)", day: day, hour: hour, minute: minute)
        }
    }
}
