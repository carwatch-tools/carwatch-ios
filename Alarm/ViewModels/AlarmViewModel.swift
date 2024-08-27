import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var timedAlarms: [Alarm] = [Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false, salivaId: -1)] {
        didSet {
            updateTimedAlarmActivity()
            saveTimedAlarms()
        }
    }
    @Published var studyDayCounter: Int = 0 {
        didSet {
            saveStudyDayCounter()
        }
    }
    @Published var dateOfLastInitialAlarm: Date = Date.distantPast {
        didSet {
            print("Last init alarm updated: \(dateOfLastInitialAlarm)")
            saveDateOfLastInitialAlarm()
        }
    }
    @Published var timedAlarmActivity: [Bool] = [false]
    // no didSet required because this info is retrieved from timedAlarms and automatically updated when timedAlarms is set
    
    let timedAlarmDataKey = "alarmsList"
    let studyDayCounterKey = "studyDayCounter"
    let dateOfLastInitialAlarmKey = "dateOfLastInitialAlarm"
    
    init() {
        getAlarmData()
        getStudyDayCounterData()
        getLastInitialAlarmData()
        print("loaded init alarm last day: \(dateOfLastInitialAlarm)")
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
    
    func getStudyDayCounterData() {
        studyDayCounter = UserDefaults.standard.integer(forKey: studyDayCounterKey)
    }
    
    func getLastInitialAlarmData() {
        guard
            let dateOfLastInitialAlarmData = UserDefaults.standard.data(forKey: dateOfLastInitialAlarmKey),
            let savedDateOfLastInitialAlarm = try? JSONDecoder().decode(Date.self, from: dateOfLastInitialAlarmData)
        else {
            return
        }
        dateOfLastInitialAlarm = savedDateOfLastInitialAlarm
    }
    
    func getInitialAlarm() -> Alarm {
        return timedAlarms[0]
    }
    
    func setInitialAlarm(alarm: Alarm) {
        timedAlarms[0] = alarm
    }
    
    func setInitialAlarmTriggered() {
        timedAlarms[0] = timedAlarms[0].setTriggered()
        dateOfLastInitialAlarm = Date()
        studyDayCounter += 1
    }
    
    func getAlarmById(alarmId: String) -> Alarm? {
        if let alarmIdx = timedAlarms.firstIndex(where: { $0.id == alarmId }) {
            return timedAlarms[alarmIdx]
        }
        return nil
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
            if alarm.isActive && alarm.isTriggered && !alarm.isScanned{
                return alarm
            }
        }
        return nil
    }
    
    func isAlarmOngoing() -> Bool {
        print("is alarm ongoing?")
        for alarm in timedAlarms {
            print(alarm)
            if alarm.isTriggered && !isDayFinished() {
                return true
            }
        }
        return false
    }
    
    func isDayFinished() -> Bool {
        for alarm in timedAlarms {
            // TODO should all samples be scanned or only active samples be scanned?
            if !alarm.isScanned {
                return false
            }
        }
        return true
    }
    
    func getTimeUntilNextInitialAlarm() -> (Int, Int) {
        let timeInterval = NSInteger(getInitialAlarm().time.timeIntervalSinceNow)
        let minutes = (timeInterval / 60) % 60
        let hours = (timeInterval / 3600)
        return (hours, minutes)
    }
    
    func setInitialAlarmActivity(isActive: Bool) {
        setInitialAlarm(alarm: getInitialAlarm().setIsActive(isActive: isActive))
        print("set init alarm activity")
        updateAlarmTime(time: getInitialAlarm().time)
        
    }
    
    func setTimedAlarmActivity(index: Int, isActive: Bool) {
        timedAlarms[index] = timedAlarms[index].setIsActive(isActive: isActive)
        if !isActive {
            NotificationManager.instance.cancelNotificationsById(alarmId: timedAlarms[index].id)
        } else {
            scheduleAlarmWithBackupNotifications(timedAlarms[index])
        }
        print("toggled: \(timedAlarms[index].isActive)")
    }
    
    func setUpcomingAlarmTriggered() {
        print("set upcoming alarm triggered")
        if let alarm = getNextUpcomingAlarm() {
            print(alarm)
            // make sure study counter is only incremented once
            if alarm.isTriggered {
                return
            }
            if alarm.id == AlarmConstants.initialAlarmId {
                setInitialAlarmTriggered()
            } else {
                modifyAlarmById(alarm: alarm.setTriggered())
            }
        }
    }
    
    func setCurrentAlarmScanned(alarmId: String? = nil) {
        print("trying to set Alarm scanned")
        var alarm: Alarm?
        if alarmId != nil {
            alarm = getAlarmById(alarmId: alarmId!)
        } else {
            alarm = getCurrentlyTriggeredAlarm()
        }
        if alarm != nil {
            // set alarm as scaned and inactive
            modifyAlarmById(alarm: alarm!.setScanned())
            // cancel all remaining alarms
            NotificationManager.instance.cancelNotificationsById(alarmId: alarm!.id)
            print("set scanned: \(alarm!)")
            print("notifications canceled for \(alarm!.id)")
        }
        if isDayFinished() && !isStudyFinished(){
            print("all alarms are scanned, day is finished")
            resetAlarmData()
        }
    }
    
    func resetAlarmData() {
        // schedule alarms for the next day after all scans for one day were finished
        for alarm in timedAlarms {
            modifyAlarmById(alarm: Alarm(id: alarm.id, isActive: true, isScanned: false, isTriggered: false, salivaId: alarm.salivaId, time: alarm.time))
        }
        updateAlarmTime(time: getInitialAlarm().time)
    }
    
    func isScanRequired() -> Bool {
        for alarm in timedAlarms {
            if alarm.isActive && alarm.isTriggered && !alarm.isScanned {
                return true
            }
        }
        return false
    }
    
    func updateAlarmTime(time: Date, scheduleInitialNotification: Bool = true) {
        /// returns true when alarms were updated successfully
        /// returns false when no update was possible because a) there was an initial alarm at the selected day already or
        /// b) the current sampling procedure is not yet finished
        print("update time")
        if isAlarmOngoing() {
            return
        }
        
        var newTime = time
        /// todays alarm was already triggered -> set for tomorrow
        if Calendar.current.isDate(dateOfLastInitialAlarm, inSameDayAs: Date()) {
            print("init alarm - setting time to next time tomorrow")
            newTime = getNextDateTimeOccurrsAfterToday(time: time)
        } else {
            print("init alarm - setting time for today")
            newTime = getNextDateTimeOccurrs(time: time)
        }
        
        setInitialAlarm(alarm: getInitialAlarm().updateTime(newTime: newTime))
        updateTimedAlarms()
        if scheduleInitialNotification {
            // schedule all notifications -> standard case when not waking up earlier than expected
            scheduleAlarmNotifications()
        } else {
            // only schedule timed notifications, as wakeup eas reported manually
            scheduleAlarmNotificationsWithoutInitial()
        }
    }
    
    private func getNextDateTimeOccurrs(time: Date) -> Date {
        /// select the Date object to the next date in the future at which the given time occurrs
        let difference = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: time)
        var updatedTime = time
        // make sure no date in the past is used, but rather the next time the selected time occurs
        if let diffDays = difference.day, let diffHours = difference.hour, let diffMins = difference.minute {
            // set day to today
            if let time = Calendar.current.date(byAdding: .day, value: -diffDays, to: updatedTime) {
                updatedTime = time
            }
            if diffHours < 0 || diffMins < 0 {
                // selected time is in the past -> add one more day
                if let time = Calendar.current.date(byAdding: .day, value: 1, to: updatedTime) {
                    updatedTime = time
                }
            }
        }
        return updatedTime
    }
    
    private func getNextDateTimeOccurrsAfterToday(time: Date) -> Date {
        /// select the Date object to the next date after the current day at which the given time occurrs
        let updatedTime = getNextDateTimeOccurrs(time: time)
        // check if date of new time is today
        if Calendar.current.isDateInToday(updatedTime) {
            // Add one day to the date
            if let updatedTime = Calendar.current.date(byAdding: .day, value: 1, to: updatedTime) {
                return updatedTime
            }
        }
        return updatedTime
    }
    
    func updateTimedAlarms() {
        // TODO: access intervals from study configuration
        var dummyIntervals = [0, 2, 4, 6]
        if dummyIntervals.count != timedAlarms.count {
            // if timed alarms is set for the first time -> create entire array
            var updatedTimedAlarms = [Alarm]()
            for (index, interval) in dummyIntervals.enumerated() {
                print("first time")
                let id = index == 0 ? AlarmConstants.initialAlarmId : "\(AlarmConstants.timedAlarmId)_\(index)"
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
    
    func updateTimedAlarmActivity() {
        var alarmsActive = [Bool]()
        for alarm in timedAlarms {
            alarmsActive.append(alarm.isActive)
        }
        timedAlarmActivity = alarmsActive
    }
    
    func updateAlarmStatus() {
        // check if any unscanned alarms are in the past
        for alarm in timedAlarms {
            if !alarm.isScanned && !alarm.isTriggered && alarm.time < Date(){
                // triggering the initial alarm requires to update the day counter and date of last initial alarm
                if alarm.id == AlarmConstants.initialAlarmId {
                    setInitialAlarmTriggered()
                } else {
                    modifyAlarmById(alarm: alarm.setTriggered())
                }
            }
        }
    }
    
    func saveTimedAlarms() {
        if let encodedTimedAlarms = try? JSONEncoder().encode(timedAlarms) {
            UserDefaults.standard.set(encodedTimedAlarms, forKey: timedAlarmDataKey)
        }
    }
    
    func saveStudyDayCounter() {
        UserDefaults.standard.set(studyDayCounter, forKey: studyDayCounterKey)
    }
    
    func saveDateOfLastInitialAlarm() {
        if let encodedDateOfLastInitialAlarm = try? JSONEncoder().encode(dateOfLastInitialAlarm) {
            UserDefaults.standard.set(encodedDateOfLastInitialAlarm, forKey: dateOfLastInitialAlarmKey)
        }
    }
    
    func scheduleAlarmNotifications() {
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
    
    func scheduleAlarmNotificationsWithoutInitial() {
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // schedule notifications for all but the intial alarm
        for (index, alarm) in timedAlarms.enumerated() where index > 0 {
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
    
    func isStudyFinished() -> Bool {
        print("Study finished? Study day counter: \(studyDayCounter)")
        // TODO use configured study duration
        let studyDuration = 1
        return studyDayCounter == studyDuration
    }
}
