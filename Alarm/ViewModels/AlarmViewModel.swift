import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var timedAlarms: [Alarm]  = [Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false)]  {
        didSet {
            updateTimedAlarmActivity()
            saveTimedAlarms()
        }
    }
    @Published var isEveningScanned: Bool = false {
        didSet {
            UserDefaults.standard.set(isEveningScanned, forKey: isEveningScannedKey)
        }
    }
    @Published var studyDayCounter: Int = 0 {
        didSet {
            UserDefaults.standard.set(studyDayCounter, forKey: studyDayCounterKey)
        }
    }
    @Published var dateOfLastInitialAlarm: Date = Date.distantPast {
        didSet {
            print("Last init alarm updated: \(dateOfLastInitialAlarm)")
            saveDateOfLastInitialAlarm()
        }
    }
    @Published var isDarkModeOn: Bool = false {
        didSet {
            print("dark mode: \(isDarkModeOn)")
            UserDefaults.standard.set(isDarkModeOn, forKey: isDarkModeOnKey)
        }
    }
    
    // no didSet required because this info is retrieved from timedAlarms and automatically updated when timedAlarms is set
    @Published var timedAlarmActivity: [Bool] = [false]
    
    // no didSet required because these are shared properties with the study data view model
    @Published var timeIntervals: [Int] = [Int]()
    @Published var numStudyDays: Int = 0
    @Published var hasEveningSample: Bool = false
    
    let timedAlarmDataKey = "alarmsList"
    let isEveningScannedKey = "isEveningScanned"
    let studyDayCounterKey = "studyDayCounter"
    let dateOfLastInitialAlarmKey = "dateOfLastInitialAlarm"
    let isDarkModeOnKey = "isDarkModeOn"
    
    init() {
        getAlarmData()
        getStudyDayCounterData()
        getLastInitialAlarmData()
        print("loaded init alarm last day: \(dateOfLastInitialAlarm)")
    }
    
    func getAlarmData() {
        isEveningScanned = UserDefaults.standard.bool(forKey: isEveningScannedKey)
        isDarkModeOn = UserDefaults.standard.bool(forKey: isDarkModeOnKey)
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
    
    func getAlarmById(alarmId: Int) -> Alarm? {
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
        if hasEveningSample && !isEveningScanned {
            return false
        }
        for alarm in timedAlarms {
            // TODO should all samples be scanned or only active samples be scanned to consider a day finished?
            if !alarm.isScanned {
                return false
            }
        }
        
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraDayCounter] = studyDayCounter
        Logger.instance.log(tag: LoggerConstants.loggerActionDayFinished, message: msg)
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
    
    func setCurrentAlarmScanned(alarmId: Int? = nil) {
        print("trying to set Alarm scanned")
        var alarm: Alarm?
        switch alarmId {
        case nil:
            alarm = getCurrentlyTriggeredAlarm()
        case AlarmConstants.eveningAlarmId:
            alarm = nil
            isEveningScanned = true
        default:
            alarm = getAlarmById(alarmId: alarmId!)
        }
        
        if alarm != nil {
            // set alarm as scanned and inactive
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
        isEveningScanned = false
        // schedule alarms for the next day after all scans for one day were finished
        for alarm in timedAlarms {
            modifyAlarmById(alarm: Alarm(id: alarm.id, isActive: true, isScanned: false, isTriggered: false, time: alarm.time))
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
        if timeIntervals.isEmpty {
            // do nothing until study was configured
            return
        }
        var previousAlarmTime = getInitialAlarm().time
        if timeIntervals.count != timedAlarms.count {
            // if timed alarms is set for the first time -> create entire array
            var updatedTimedAlarms = [Alarm]()
            for (index, interval) in timeIntervals.enumerated() {
                let newAlarmTime = previousAlarmTime.addingTimeInterval(TimeInterval(interval * 60))
                updatedTimedAlarms.append(Alarm(id: index, isActive: getInitialAlarm().isActive, time: newAlarmTime))
                previousAlarmTime = newAlarmTime
            }
            timedAlarms = updatedTimedAlarms
            
            // if timed alarm was set before -> only update entries
        } else {
            for (index, interval) in timeIntervals.enumerated() {
                let currentAlarm = timedAlarms[index]
                let newAlarmTime = previousAlarmTime.addingTimeInterval(TimeInterval(interval * 60))
                timedAlarms[index] = Alarm(id: currentAlarm.id, isActive: currentAlarm.isActive, isScanned: currentAlarm.isScanned, isTriggered: currentAlarm.isTriggered, time: newAlarmTime)
                previousAlarmTime = newAlarmTime
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
            if alarm.isActive && !alarm.isScanned && !alarm.isTriggered && alarm.time < Date(){
                // triggering the initial alarm requires to update the day counter and date of last initial alarm
                if alarm.id == AlarmConstants.initialAlarmId {
                    setInitialAlarmTriggered()
                } else {
                    modifyAlarmById(alarm: alarm.setTriggered())
                }
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraAlarmId] = alarm.id
                Logger.instance.log(tag: LoggerConstants.loggerActionAlarmReceived, message: msg)
            }
        }
    }
    
    func saveTimedAlarms() {
        if let encodedTimedAlarms = try? JSONEncoder().encode(timedAlarms) {
            UserDefaults.standard.set(encodedTimedAlarms, forKey: timedAlarmDataKey)
        }
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
        return isDayFinished() && studyDayCounter == numStudyDays
    }
    
    func resetAlarmDataForNewUser() {
        timedAlarms = [Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false)]
        isEveningScanned = false
        studyDayCounter = 0
        isDarkModeOn = false
        dateOfLastInitialAlarm = Date.distantPast
        timedAlarmActivity = [false]
    }
}
