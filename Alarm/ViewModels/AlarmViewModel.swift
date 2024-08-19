import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var timedAlarms: [Alarm] = [Alarm(id: "initial", isActive: false, isScanned: false, isTriggered: false, salivaId: -1)] {
        didSet {
            saveTimedAlarms()
        }
    }
    
    let timedAlarmDataKey = "alarmsList"
    
    init() {
        getAlarmData()
    }
    
    func getAlarmData() {
        guard
            let timedAlarmData = UserDefaults.standard.data(forKey: timedAlarmDataKey),
            let savedTimedAlarms = try? JSONDecoder().decode([Alarm].self, from: timedAlarmData)
        else {
            return
        }
        timedAlarms = savedTimedAlarms
        updateAlarmTime(time: getInitialAlarm().time)
    }
    
    func getInitialAlarm() -> Alarm {
        return timedAlarms[0]
    }
    
    func setInitialAlarm(alarm: Alarm) {
        timedAlarms[0] = alarm
    }
    
    func modifyAlarmById(alarm: Alarm) {
        if let alarmIdx = timedAlarms.firstIndex(where: { $0.id == alarm.id }) {
            print("modifying alarm with index \(alarmIdx)")
            print(alarm)
            timedAlarms[alarmIdx] = alarm
        }
        else {
            print("Alarm \(alarm.id) does not exist in alarms list")
        }
    }
    
    func getNextUpcomingAlarm() -> Alarm? {
        for alarm in timedAlarms {
            if alarm.isActive && !alarm.isScanned {
                return alarm
            }
        }
        return nil
    }
    
    func getCurrentlyTriggeredAlarm() -> Alarm? {
        for alarm in timedAlarms {
            print(alarm)
            if alarm.isActive && alarm.isTriggered && !alarm.isScanned{
                return alarm
            }
        }
        return nil
    }
    
    func isDayFinished() -> Bool {
        for alarm in timedAlarms {
            if !alarm.isScanned {
                return false
            }
        }
        return true
    }
    
    func getAlarmActiveInfo() -> [Bool] {
        var alarmsActive = [Bool]()
        for alarm in timedAlarms {
            alarmsActive.append(alarm.isActive)
        }
        return alarmsActive
    }
    
    func getTimeUntilNextInitialAlarm() -> (Int, Int) {
        let timeInterval = NSInteger(getInitialAlarm().time.timeIntervalSinceNow)
        let minutes = (timeInterval / 60) % 60
        let hours = (timeInterval / 3600)
        return (hours, minutes)
    }
    
    func setInitialAlarmActivity(isActive: Bool) {
        setInitialAlarm(alarm: getInitialAlarm().setIsActive(isActive: isActive))
        updateAlarmTime(time: getInitialAlarm().time)
        
    }
    
    func setTimedAlarmActivity(index: Int, isActive: Bool) {
        timedAlarms[index] = timedAlarms[index].setIsActive(isActive: isActive)
        print("toggled: \(timedAlarms[index].isActive)")
    }
    
    func setUpcomingAlarmTriggered() {
        print("set upcoming alarm triggered")
        if let alarm = getNextUpcomingAlarm() {
            print(alarm)
            modifyAlarmById(alarm: alarm.setTriggered())
        }
    }
    
    func setCurrentAlarmScanned() {
        print("trying to set Alarm scanned")
        if let alarm = getCurrentlyTriggeredAlarm() {
            modifyAlarmById(alarm: alarm.setScanned())
            // cancel all remaining alarms
            NotificationManager.instance.cancelNotificationsById(alarmId: alarm.id)
            print("set scanned: \(alarm.isScanned)")
            print("notifications canceled for \(alarm.id)")
        }
        if isDayFinished(){
            print("all alarms are scanned, day is finished")
            // TODO: schedule subsequent reminders/alarm for next day
        }
    }
    
    func isScanRequired() -> Bool {
        for alarm in timedAlarms {
            if alarm.isActive && alarm.isTriggered && !alarm.isScanned {
                return true
            }
        }
        return false
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
        setInitialAlarm(alarm: getInitialAlarm().updateTime(newTime: newTime))
        updateTimedAlarms()
        scheduleAlarmNotifications()
    }
    
    func updateTimedAlarms() {
        // TODO: access intervals from study configuration
        // TODO: make sure the initial alarm is also included
        // TODO: only allow when no scanning procedure is ongoing?
        var dummyIntervals = [0, 2, 4, 6]
        if dummyIntervals.count != timedAlarms.count {
            // if timed alarms is set for the first time -> create entire array
            var updatedTimedAlarms = [Alarm]()
            for (index, interval) in dummyIntervals.enumerated() {
                print("first time")
                let id = index == 0 ? "initial" : "timed_\(index)"
                updatedTimedAlarms.append(Alarm(id: id, isActive: getInitialAlarm().isActive, salivaId: index, time: getInitialAlarm().time.addingTimeInterval(TimeInterval(interval * 60))))
            }
            timedAlarms = updatedTimedAlarms
            
            // if timed alarm was set before -> only update entries
        } else {
            for (index, interval) in dummyIntervals.enumerated() {
                let currentAlarm = timedAlarms[index]
                timedAlarms[index] = Alarm(id: currentAlarm.id, isActive: currentAlarm.isActive, isScanned: currentAlarm.isScanned, isTriggered: currentAlarm.isTriggered, salivaId: currentAlarm.salivaId, time: getInitialAlarm().time.addingTimeInterval(TimeInterval(interval * 60)))
            }
        }
        
    }
    
    func saveTimedAlarms() {
        if let encodedTimedAlarms = try? JSONEncoder().encode(timedAlarms) {
            UserDefaults.standard.set(encodedTimedAlarms, forKey: timedAlarmDataKey)
        }
    }
    
    func scheduleAlarmNotifications() {
        print("schedule alarm with backup notifications")
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // do not schedule new notifications if alarm toggle is set inactive
        if !getInitialAlarm().isActive {
            return
        }
        for alarm in timedAlarms {
            scheduleAlarmWithBackupNotifications(alarm)
        }
    }
    
    func scheduleAlarmWithBackupNotifications(_ alarm: Alarm){
        for i in 0..<NotificationConstants.numberOfSubsequentNotifications {
            print("scheduling alarm \(alarm.id)")
            // calculate notification time
            guard let notificationTime = alarm.getCurrentAlarmTimePlusInterval(numMinutes: i * NotificationConstants.minutesBetweenNotifications) else {
                return
            }
            let (day, hour, minute) = getDayHourMinuteFromTime(time: notificationTime)
            // set notification for next day at the given alarm time
            NotificationManager.instance.scheduleCalendarBasedNotification(id: "\(alarm.id)_\(i)", day: day, hour: hour, minute: minute)
        }
    }
}
