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
            saveDateOfLastInitialAlarm()
        }
    }
    @Published var isDarkModeOn: Bool? = nil {
        didSet {
            if let isDarkModeOn {
                UserDefaults.standard.set(isDarkModeOn, forKey: isDarkModeOnKey)
            } else {
                UserDefaults.standard.removeObject(forKey: isDarkModeOnKey)
            }
        }
    }
    @Published var didCompleteLastScheduledSample: Bool = false
    
    // no didSet required because this info is retrieved from timedAlarms and automatically updated when timedAlarms is set
    @Published var timedAlarmActivity: [Bool] = [false]
    
    // no didSet required because these are shared properties with the study data view model
    @Published var timeIntervals: [Int] = [Int]()
    @Published var fixedTimes: [Time] = [Time]()
    @Published var numStudyDays: Int = 0
    @Published var hasEveningSample: Bool = false
    @Published var startSample: Int = 1
    
    let timedAlarmDataKey = "alarmsList"
    let isEveningScannedKey = "isEveningScanned"
    let studyDayCounterKey = "studyDayCounter"
    let dateOfLastInitialAlarmKey = "dateOfLastInitialAlarm"
    let isDarkModeOnKey = "isDarkModeOn"
    
    init() {
        getAlarmData()
        getStudyDayCounterData()
        getLastInitialAlarmData()
    }

    private func defaultInitialAlarm() -> Alarm {
        Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false)
    }

    private func ensureInitialAlarmExists() {
        if timedAlarms.isEmpty {
            timedAlarms = [defaultInitialAlarm()]
        }
    }
    
    func getAlarmData() {
        isEveningScanned = UserDefaults.standard.bool(forKey: isEveningScannedKey)
        if let isDarkModeOn = UserDefaults.standard.object(forKey: isDarkModeOnKey) as? Bool {
            self.isDarkModeOn = isDarkModeOn
        } else {
            self.isDarkModeOn = nil
        }
        guard
            let timedAlarmData = UserDefaults.standard.data(forKey: timedAlarmDataKey),
            let savedTimedAlarms = try? JSONDecoder().decode([Alarm].self, from: timedAlarmData)
        else {
            return
        }
        timedAlarms = savedTimedAlarms.isEmpty ? [defaultInitialAlarm()] : savedTimedAlarms
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
        ensureInitialAlarmExists()
        return timedAlarms[0]
    }
    
    func setInitialAlarm(alarm: Alarm) {
        ensureInitialAlarmExists()
        timedAlarms[0] = alarm
    }
    
    func setInitialAlarmTriggered() {
        ensureInitialAlarmExists()
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
            print("Modifying alarm with id \(alarm.id)")
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
            if alarm.isTriggered && !isDayFinished() {
                print("Ongoing alarm: \(alarm.id)")
                return true
            }
        }
        print("No ongoing alarm")
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
        /// called when initial alarm activity is toggled
        setInitialAlarm(alarm: getInitialAlarm().setIsActive(isActive: isActive))
        updateAlarmTime(time: getInitialAlarm().time)
        
    }
    
    func setTimedAlarmActivity(index: Int, isActive: Bool) {
        guard timedAlarms.indices.contains(index) else {
            return
        }
        timedAlarms[index] = timedAlarms[index].setIsActive(isActive: isActive)
        if !isActive {
            NotificationManager.instance.cancelNotificationsById(alarmId: timedAlarms[index].id)
        } else {
            scheduleAlarmWithBackupNotifications(timedAlarms[index])
        }
    }
    
    func setUpcomingAlarmTriggered() {
        if let alarm = getNextUpcomingAlarm() {
            // make sure study counter is only incremented once
            if alarm.isTriggered {
                return
            }
            if alarm.id == AlarmConstants.initialAlarmId {
                setInitialAlarmTriggered()
            } else {
                modifyAlarmById(alarm: alarm.setTriggered())
            }
            print("Alarm \(alarm.id) set as triggered")
        }
    }
    
    func setCurrentAlarmScanned(alarmId: Int? = nil) {
        var alarm: Alarm?
        didCompleteLastScheduledSample = false
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
            didCompleteLastScheduledSample = alarm?.id == timedAlarms.last?.id
            // set alarm as scanned and inactive
            modifyAlarmById(alarm: alarm!.setScanned())
            // cancel all remaining alarms
            NotificationManager.instance.cancelNotificationsById(alarmId: alarm!.id)
            print("Alarm \(alarm!.id) set  as scanned")
        }
        if isDayFinished() && !isStudyFinished(){
            print("All alarms are scanned, day is finished")
            resetAlarmData()
        }
    }
    
    func resetAlarmData() {
        /// called after a day is finished
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
            print("Setting next alarm for tomorrow")
            newTime = getNextDateTimeOccurrsAfterToday(time: time)
        } else {
            print("Setting next alarm for today")
            newTime = getNextDateTimeOccurrs(time: time)
        }
        
        setInitialAlarm(alarm: getInitialAlarm().updateTime(newTime: newTime))
        updateTimedAlarms()
        if scheduleInitialNotification {
            // schedule all notifications -> standard case when not waking up earlier than expected
            scheduleAlarmNotifications()
        } else {
            // only schedule timed notifications, as wakeup was reported manually
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
        ensureInitialAlarmExists()

        if timeIntervals.isEmpty && fixedTimes.isEmpty {
            // do nothing until study was configured
            return
        }

        let updatedAlarmTimes = updateAlarmTimes()

        let initialAlarm = getInitialAlarm()
        let expectedAlarmCount = updatedAlarmTimes.count + 1

        if timedAlarms.count != expectedAlarmCount {
            // Rebuild the list when the configured sample count changed, while preserving
            // the current initial alarm state at index 0.
            var rebuiltAlarms = [initialAlarm]
            for (offset, time) in updatedAlarmTimes.enumerated() {
                rebuiltAlarms.append(
                    Alarm(id: offset + 1, isActive: initialAlarm.isActive, time: time)
                )
            }
            timedAlarms = rebuiltAlarms
        } else {
            for (offset, time) in updatedAlarmTimes.enumerated() {
                let index = offset + 1
                let currentAlarm = timedAlarms[index]
                timedAlarms[index] = Alarm(
                    id: currentAlarm.id,
                    isActive: currentAlarm.isActive,
                    isScanned: currentAlarm.isScanned,
                    isTriggered: currentAlarm.isTriggered,
                    time: time
                )
            }
        }
    }
    
    private func updateAlarmTimes() -> [Date] {
        var previousAlarmTime = getInitialAlarm().time
        var updatedAlarmTimes = [Date]()
        for interval in timeIntervals {
            // add times of timed alarms
            let newAlarmTime = previousAlarmTime.addingTimeInterval(TimeInterval(interval * 60))
            updatedAlarmTimes.append(newAlarmTime)
            previousAlarmTime = newAlarmTime
        }
        for time in fixedTimes {
            // add times of fixed alarms
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: getInitialAlarm().time)
            dc.hour = time.hour
            dc.minute = time.minute
            if let fixedTime = Calendar.current.date(from: dc) {
                updatedAlarmTimes.append(fixedTime)
            }
        }
        // bring times in correct chronological order
        updatedAlarmTimes.sort()
        return updatedAlarmTimes
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
            logAlarmScheduled(alarm)
        }
    }
    
    func scheduleAlarmWithBackupNotifications(_ alarm: Alarm){
        for i in 0..<NotificationConstants.numberOfSubsequentNotifications {
            // calculate notification time
            guard let notificationTime = alarm.getCurrentAlarmTimePlusInterval(numMinutes: i * NotificationConstants.minutesBetweenNotifications) else {
                return
            }
            let (day, hour, minute) = getDayHourMinuteFromTime(time: notificationTime)
            let salivaId = "\(startSample + alarm.id)"
            // set notification for next day at the given alarm time
            NotificationManager.instance.scheduleCalendarBasedNotification(id: "\(alarm.id)_\(i)", salivaId: salivaId, day: day, hour: hour, minute: minute)
        }
    }
    
    func logAlarmScheduled(_ alarm: Alarm){
        print("Alarm \(alarm.id) was scheduled")
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraAlarmId] = alarm.id
        msg[LoggerConstants.loggerExtraAlarmTimestamp] = getUnixTimeMillisFromDate(alarm.time)
        msg[LoggerConstants.loggerTranslatedTimestamp] = formatDateForLogs(alarm.time)
        Logger.instance.log(tag: LoggerConstants.loggerActionAlarmSet, message: msg)
    }
    
    func isStudyFinished() -> Bool {
        let isFinished = isDayFinished() && studyDayCounter == numStudyDays
        print("Study finished: \(isFinished)")
        return isFinished
    }
    
    func resetAlarmDataForNewUser() {
        timedAlarms = [Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false)]
        isEveningScanned = false
        studyDayCounter = 0
        isDarkModeOn = nil
        dateOfLastInitialAlarm = Date.distantPast
        timedAlarmActivity = [false]
    }
}
