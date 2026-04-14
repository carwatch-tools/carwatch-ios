import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var initialAlarm: Alarm = Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false) {
        didSet {
            saveInitialAlarm()
        }
    }
    @Published var timedAlarms: [Alarm]  = []  {
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
    @Published var eveningReminderTime: Date? = nil {
        didSet {
            saveEveningReminderTime()
        }
    }
    @Published var shouldPromptForEveningReminderSetup = false
    
    // no didSet required because this info is retrieved from timedAlarms and automatically updated when timedAlarms is set
    @Published var timedAlarmActivity: [Bool] = [false]
    
    // no didSet required because these are shared properties with the study data view model
    @Published var timeIntervals: [Int] = [Int]()
    @Published var fixedTimes: [Time] = [Time]()
    @Published var numStudyDays: Int = 0
    @Published var hasEveningSample: Bool = false
    @Published var startSample: Int = 1
    
    let initialAlarmDataKey = "initialAlarm"
    let timedAlarmDataKey = "alarmsList"
    let isEveningScannedKey = "isEveningScanned"
    let studyDayCounterKey = "studyDayCounter"
    let dateOfLastInitialAlarmKey = "dateOfLastInitialAlarm"
    let isDarkModeOnKey = "isDarkModeOn"
    let eveningReminderTimeKey = "eveningReminderTime"
    
    init() {
        getAlarmData()
        getStudyDayCounterData()
        getLastInitialAlarmData()
    }

    private func defaultInitialAlarm() -> Alarm {
        Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false)
    }

    private func migratedInitialAlarm(from legacyTimedAlarms: [Alarm]) -> Alarm {
        guard let firstSampleAlarm = legacyTimedAlarms.min(by: { $0.id < $1.id }) else {
            return defaultInitialAlarm()
        }

        return Alarm(
            id: AlarmConstants.initialAlarmId,
            isActive: false,
            isScanned: false,
            isTriggered: false,
            time: firstSampleAlarm.time
        )
    }
    
    func getAlarmData() {
        isEveningScanned = UserDefaults.standard.bool(forKey: isEveningScannedKey)
        if let isDarkModeOn = UserDefaults.standard.object(forKey: isDarkModeOnKey) as? Bool {
            self.isDarkModeOn = isDarkModeOn
        } else {
            self.isDarkModeOn = nil
        }
        if let eveningReminderTimeData = UserDefaults.standard.data(forKey: eveningReminderTimeKey),
           let savedEveningReminderTime = try? JSONDecoder().decode(Date.self, from: eveningReminderTimeData) {
            eveningReminderTime = savedEveningReminderTime
        } else {
            eveningReminderTime = nil
        }

        let savedInitialAlarm = UserDefaults.standard.data(forKey: initialAlarmDataKey)
            .flatMap { try? JSONDecoder().decode(Alarm.self, from: $0) }

        if let savedInitialAlarm {
            initialAlarm = savedInitialAlarm
        }

        if let timedAlarmData = UserDefaults.standard.data(forKey: timedAlarmDataKey),
           let savedTimedAlarms = try? JSONDecoder().decode([Alarm].self, from: timedAlarmData) {
            if savedInitialAlarm == nil {
                // Legacy builds stored only scheduled sample alarms. Preserve their IDs and
                // migrate the dedicated wakeup alarm separately to avoid reassigning sample state.
                initialAlarm = migratedInitialAlarm(from: savedTimedAlarms)
            }

            timedAlarms = savedTimedAlarms
        }

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
        return initialAlarm
    }
    
    func setInitialAlarm(alarm: Alarm) {
        initialAlarm = alarm
    }
    
    func setInitialAlarmTriggered() {
        initialAlarm = initialAlarm.setTriggered()
        dateOfLastInitialAlarm = Date()
        studyDayCounter += 1
    }

    func confirmWakeup(at wakeupTime: Date) {
        setInitialAlarm(
            alarm: Alarm(
                id: AlarmConstants.initialAlarmId,
                isActive: true,
                isScanned: false,
                isTriggered: false,
                time: wakeupTime
            )
        )

        updateTimedAlarms()
        rebaseTimedAlarmsAfterWakeupConfirmation(referenceTime: wakeupTime)
        scheduleAlarmNotificationsWithoutInitial()
        setInitialAlarmTriggered()
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
            scheduleAlarmWithBackupNotifications(timedAlarms[index], salivaId: "\(startSample + timedAlarms[index].id)")
        }
    }
    
    func setUpcomingAlarmTriggered() {
        if initialAlarm.isActive && !initialAlarm.isTriggered && !Calendar.current.isDate(dateOfLastInitialAlarm, inSameDayAs: Date()) {
            setInitialAlarmTriggered()
            _ = triggerWakeupSampleIfNeeded()
            print("Alarm \(initialAlarm.id) set as triggered")
            return
        }

        if let alarm = getNextUpcomingAlarm() {
            // make sure study counter is only incremented once
            if alarm.isTriggered {
                return
            }
            modifyAlarmById(alarm: alarm.setTriggered())
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
            cancelEveningReminder()
        default:
            alarm = getAlarmById(alarmId: alarmId!)
        }
        
        if alarm != nil {
            // set alarm as scanned and inactive
            modifyAlarmById(alarm: alarm!.setScanned())
            didCompleteLastScheduledSample = !timedAlarms.contains(where: { $0.isActive && !$0.isScanned })
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
        cancelEveningReminder()
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
        if timeIntervals.isEmpty && fixedTimes.isEmpty {
            // do nothing until study was configured
            return
        }

        let updatedAlarmTimes = updateAlarmTimes()
        let expectedAlarmCount = updatedAlarmTimes.count

        if timedAlarms.count != expectedAlarmCount {
            for (offset, time) in updatedAlarmTimes.enumerated() {
                let rebuiltAlarm = Alarm(
                    id: offset,
                    isActive: initialAlarm.isActive,
                    time: time
                )
                if timedAlarms.indices.contains(offset) {
                    timedAlarms[offset] = Alarm(
                        id: rebuiltAlarm.id,
                        isActive: timedAlarms[offset].isActive,
                        isScanned: timedAlarms[offset].isScanned,
                        isTriggered: timedAlarms[offset].isTriggered,
                        time: time
                    )
                } else {
                    timedAlarms.append(rebuiltAlarm)
                }
            }
            if timedAlarms.count > expectedAlarmCount {
                timedAlarms.removeLast(timedAlarms.count - expectedAlarmCount)
            }
        } else {
            for (offset, time) in updatedAlarmTimes.enumerated() {
                let currentAlarm = timedAlarms[offset]
                timedAlarms[offset] = Alarm(
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

    private func rebaseTimedAlarmsAfterWakeupConfirmation(referenceTime: Date) {
        timedAlarms = timedAlarms.map { alarm in
            guard !alarm.isScanned else {
                return alarm
            }

            return Alarm(
                id: alarm.id,
                isActive: true,
                isScanned: false,
                isTriggered: alarm.time <= referenceTime,
                time: alarm.time
            )
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
        if initialAlarm.isActive && !initialAlarm.isTriggered && initialAlarm.time < Date() {
            setInitialAlarmTriggered()
            _ = triggerWakeupSampleIfNeeded()
            var msg = [String: Any]()
            msg[LoggerConstants.loggerExtraAlarmId] = initialAlarm.id
            Logger.instance.log(tag: LoggerConstants.loggerActionAlarmReceived, message: msg)
        }

        // check if any unscanned alarms are in the past
        for alarm in timedAlarms {
            if alarm.isActive && !alarm.isScanned && !alarm.isTriggered && alarm.time < Date(){
                modifyAlarmById(alarm: alarm.setTriggered())
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraAlarmId] = alarm.id
                Logger.instance.log(tag: LoggerConstants.loggerActionAlarmReceived, message: msg)
            }
        }
    }

    func scheduleEveningReminder(time: Date, eveningSampleId: Int) {
        let scheduledTime = getNextDateTimeOccurrs(time: time)
        let eveningAlarm = Alarm(id: AlarmConstants.eveningAlarmId, isActive: true, time: scheduledTime)

        cancelEveningReminder()
        eveningReminderTime = scheduledTime
        scheduleAlarmWithBackupNotifications(eveningAlarm, salivaId: "\(eveningSampleId)")
        logAlarmScheduled(eveningAlarm)
        shouldPromptForEveningReminderSetup = false
    }

    func cancelEveningReminder() {
        eveningReminderTime = nil
        shouldPromptForEveningReminderSetup = false
        NotificationManager.instance.cancelNotificationsById(alarmId: AlarmConstants.eveningAlarmId)
    }
    
    func saveTimedAlarms() {
        if let encodedTimedAlarms = try? JSONEncoder().encode(timedAlarms) {
            UserDefaults.standard.set(encodedTimedAlarms, forKey: timedAlarmDataKey)
        }
    }
    
    func saveInitialAlarm() {
        if let encodedInitialAlarm = try? JSONEncoder().encode(initialAlarm) {
            UserDefaults.standard.set(encodedInitialAlarm, forKey: initialAlarmDataKey)
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
        scheduleAlarmWithBackupNotifications(getInitialAlarm(), salivaId: nil)
        for alarm in timedAlarms {
            scheduleAlarmWithBackupNotifications(alarm, salivaId: "\(startSample + alarm.id)")
        }
    }
    
    func scheduleAlarmNotificationsWithoutInitial() {
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // schedule notifications for all sample reminders, but not the wakeup alarm
        for alarm in timedAlarms {
            scheduleAlarmWithBackupNotifications(alarm, salivaId: "\(startSample + alarm.id)")
            logAlarmScheduled(alarm)
        }
    }
    
    func scheduleAlarmWithBackupNotifications(_ alarm: Alarm, salivaId: String?){
        for i in 0..<NotificationConstants.numberOfSubsequentNotifications {
            // calculate notification time
            guard let notificationTime = alarm.getCurrentAlarmTimePlusInterval(numMinutes: i * NotificationConstants.minutesBetweenNotifications) else {
                return
            }
            let (day, hour, minute) = getDayHourMinuteFromTime(time: notificationTime)
            // set notification for next day at the given alarm time
            NotificationManager.instance.scheduleCalendarBasedNotification(id: "\(alarm.id)_\(i)", salivaId: salivaId, day: day, hour: hour, minute: minute)
        }
    }

    func triggerWakeupSampleIfNeeded() -> Alarm? {
        guard let firstTimedAlarm = timedAlarms.first else {
            return nil
        }

        let sameMinuteAsWakeup = Calendar.current.compare(
            firstTimedAlarm.time,
            to: initialAlarm.time,
            toGranularity: .minute
        ) == .orderedSame

        guard sameMinuteAsWakeup, !firstTimedAlarm.isTriggered, !firstTimedAlarm.isScanned else {
            return nil
        }

        let triggeredAlarm = firstTimedAlarm.setTriggered()
        modifyAlarmById(alarm: triggeredAlarm)
        return triggeredAlarm
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
        initialAlarm = defaultInitialAlarm()
        timedAlarms = []
        isEveningScanned = false
        studyDayCounter = 0
        isDarkModeOn = nil
        eveningReminderTime = nil
        shouldPromptForEveningReminderSetup = false
        dateOfLastInitialAlarm = Date.distantPast
        timedAlarmActivity = []
    }

    private func saveEveningReminderTime() {
        if let eveningReminderTime {
            if let encodedEveningReminderTime = try? JSONEncoder().encode(eveningReminderTime) {
                UserDefaults.standard.set(encodedEveningReminderTime, forKey: eveningReminderTimeKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: eveningReminderTimeKey)
        }
    }
}
