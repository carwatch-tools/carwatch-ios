import Foundation

enum DayFinishReason: String {
    case completedAllSamples = "completed_all_samples"
    case userFinishedDay = "user_finished_day"
    case selectedCurrentDateForScan = "selected_current_date_for_scan"
    case completedPreviousDayAfterLateScan = "completed_previous_day_after_late_scan"
    case recoveredOnWakeup = "recovered_on_wakeup"
}

struct StudyDaySummary: Codable {
    let studyDay: Int
    let timedAlarms: [Alarm]
    let hasEveningSample: Bool
    let isEveningScanned: Bool
    let eveningTime: Date?
    let finishReason: String?
    let isFinished: Bool

    var missedSampleCount: Int {
        timedAlarms.filter { !$0.isScanned }.count + (hasEveningSample && !isEveningScanned ? 1 : 0)
    }
}

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
    @Published private var lastFinishedStudyDayCounter: Int = 0 {
        didSet {
            UserDefaults.standard.set(lastFinishedStudyDayCounter, forKey: lastFinishedStudyDayCounterKey)
        }
    }
    @Published var dateOfLastInitialAlarm: Date = Date.distantPast {
        didSet {
            saveDateOfLastInitialAlarm()
        }
    }
    @Published private var dateOfLastConfirmedWakeup: Date = Date.distantPast {
        didSet {
            saveDateOfLastConfirmedWakeup()
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
    @Published var hasPendingDayReset: Bool = false
    @Published var eveningReminderTime: Date? = nil {
        didSet {
            saveEveningReminderTime()
        }
    }
    @Published var lastEveningReminderSelection: Date? = nil {
        didSet {
            saveLastEveningReminderSelection()
        }
    }
    @Published var shouldPromptForEveningReminderSetup = false
    @Published private var studyDaySummaries: [Int: StudyDaySummary] = [:] {
        didSet {
            saveStudyDaySummaries()
        }
    }
    
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
    let lastFinishedStudyDayCounterKey = "lastFinishedStudyDayCounter"
    let dateOfLastInitialAlarmKey = "dateOfLastInitialAlarm"
    let dateOfLastConfirmedWakeupKey = "dateOfLastConfirmedWakeup"
    let isDarkModeOnKey = "isDarkModeOn"
    let eveningReminderTimeKey = "eveningReminderTime"
    let lastEveningReminderSelectionKey = "lastEveningReminderSelection"
    private let pendingWakeupNotificationTimeKey = "pendingWakeupNotificationTime"
    private let pendingWakeupNotificationTimesKey = "pendingWakeupNotificationTimes"
    private let shouldFinishPreviousDayOnWakeupKey = "shouldFinishPreviousDayOnWakeup"
    private let studyDaysToFinishOnWakeupKey = "studyDaysToFinishOnWakeup"
    private let studyDaySummariesKey = "studyDaySummaries"
    private var pendingWakeupNotificationTimes: [Date] = [] {
        didSet {
            savePendingWakeupNotificationTimes()
        }
    }
    private var studyDaysToFinishOnWakeup: [Int] = [] {
        didSet {
            UserDefaults.standard.set(studyDaysToFinishOnWakeup, forKey: studyDaysToFinishOnWakeupKey)
            shouldFinishPreviousDayOnWakeup = !studyDaysToFinishOnWakeup.isEmpty
            pendingWakeupRecoveryRevision += 1
        }
    }
    private var shouldFinishPreviousDayOnWakeup = false {
        didSet {
            UserDefaults.standard.set(shouldFinishPreviousDayOnWakeup, forKey: shouldFinishPreviousDayOnWakeupKey)
        }
    }
    @Published private(set) var pendingWakeupRecoveryRevision = 0
    
    init() {
        getAlarmData()
        getStudyDayCounterData()
        getLastFinishedStudyDayCounterData()
        getLastInitialAlarmData()
        getLastConfirmedWakeupData()
        getStudyDaySummariesData()
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
        if let lastEveningReminderSelectionData = UserDefaults.standard.data(forKey: lastEveningReminderSelectionKey),
           let savedLastEveningReminderSelection = try? JSONDecoder().decode(Date.self, from: lastEveningReminderSelectionData) {
            lastEveningReminderSelection = savedLastEveningReminderSelection
        } else {
            lastEveningReminderSelection = nil
        }
        if let pendingWakeupNotificationTimesData = UserDefaults.standard.data(forKey: pendingWakeupNotificationTimesKey),
           let savedPendingWakeupNotificationTimes = try? JSONDecoder().decode([Date].self, from: pendingWakeupNotificationTimesData) {
            pendingWakeupNotificationTimes = savedPendingWakeupNotificationTimes
        } else if let pendingWakeupNotificationTimeData = UserDefaults.standard.data(forKey: pendingWakeupNotificationTimeKey),
                  let savedPendingWakeupNotificationTime = try? JSONDecoder().decode(Date.self, from: pendingWakeupNotificationTimeData) {
            pendingWakeupNotificationTimes = [savedPendingWakeupNotificationTime]
        } else {
            pendingWakeupNotificationTimes = []
        }
        shouldFinishPreviousDayOnWakeup = UserDefaults.standard.bool(forKey: shouldFinishPreviousDayOnWakeupKey)
        studyDaysToFinishOnWakeup = UserDefaults.standard.array(forKey: studyDaysToFinishOnWakeupKey) as? [Int] ?? []

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

    func getLastFinishedStudyDayCounterData() {
        lastFinishedStudyDayCounter = UserDefaults.standard.integer(forKey: lastFinishedStudyDayCounterKey)
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

    func getLastConfirmedWakeupData() {
        guard
            let dateOfLastConfirmedWakeupData = UserDefaults.standard.data(forKey: dateOfLastConfirmedWakeupKey),
            let savedDateOfLastConfirmedWakeup = try? JSONDecoder().decode(Date.self, from: dateOfLastConfirmedWakeupData)
        else {
            return
        }
        dateOfLastConfirmedWakeup = savedDateOfLastConfirmedWakeup
    }

    func getStudyDaySummariesData() {
        guard
            let data = UserDefaults.standard.data(forKey: studyDaySummariesKey),
            let summaries = try? JSONDecoder().decode([StudyDaySummary].self, from: data)
        else {
            return
        }

        studyDaySummaries = Dictionary(uniqueKeysWithValues: summaries.map { ($0.studyDay, $0) })
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
        let wasWakeupAlreadyTriggeredToday = Calendar.current.isDate(dateOfLastInitialAlarm, inSameDayAs: wakeupTime)
        let didFinishPreviousDay = finishPreviousDayForPendingWakeupIfNeeded()
        dateOfLastConfirmedWakeup = wakeupTime

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
        rebaseTimedAlarmsAfterWakeupConfirmation(now: Date())
        if wasWakeupAlreadyTriggeredToday {
            initialAlarm = initialAlarm.setTriggered()
        } else {
            setInitialAlarmTriggered()
        }
        if didFinishPreviousDay {
            isEveningScanned = false
        }
        scheduleAlarmNotificationsWithoutInitial()
    }
    
    func getAlarmById(alarmId: Int) -> Alarm? {
        if let alarmIdx = timedAlarms.firstIndex(where: { $0.id == alarmId }) {
            return timedAlarms[alarmIdx]
        }
        return nil
    }
    
    func modifyAlarmById(alarm: Alarm) {
        if let alarmIdx = timedAlarms.firstIndex(where: { $0.id == alarm.id }) {
            timedAlarms[alarmIdx] = alarm
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
        for alarm in timedAlarms {
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
            if !alarm.isScanned {
                return false
            }
        }

        return true
    }

    func markDayFinished(
        reason: DayFinishReason,
        studyDay: Int? = nil,
        timedAlarmsSnapshot: [Alarm]? = nil,
        isEveningScannedSnapshot: Bool? = nil,
        eveningTimeSnapshot: Date? = nil
    ) {
        let finishedStudyDay = studyDay ?? studyDayCounter
        saveStudyDaySummary(
            studyDay: finishedStudyDay,
            reason: reason,
            timedAlarmsSnapshot: timedAlarmsSnapshot ?? timedAlarms,
            isEveningScannedSnapshot: isEveningScannedSnapshot ?? isEveningScanned,
            eveningTimeSnapshot: eveningTimeSnapshot ?? eveningReminderTime ?? lastEveningReminderSelection
        )
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraDayCounter] = finishedStudyDay
        msg[LoggerConstants.loggerExtraDayFinishReason] = reason.rawValue
        Logger.instance.log(tag: LoggerConstants.loggerActionDayFinished, message: msg)
        lastFinishedStudyDayCounter = max(lastFinishedStudyDayCounter, finishedStudyDay)
    }

    private func saveStudyDaySummary(
        studyDay: Int,
        reason: DayFinishReason?,
        timedAlarmsSnapshot: [Alarm],
        isEveningScannedSnapshot: Bool,
        eveningTimeSnapshot: Date?
    ) {
        guard studyDay > 0 else {
            return
        }

        studyDaySummaries[studyDay] = StudyDaySummary(
            studyDay: studyDay,
            timedAlarms: timedAlarmsSnapshot,
            hasEveningSample: hasEveningSample,
            isEveningScanned: isEveningScannedSnapshot,
            eveningTime: eveningTimeSnapshot,
            finishReason: reason?.rawValue,
            isFinished: reason != nil
        )
    }

    func studyDaySummary(for studyDay: Int) -> StudyDaySummary? {
        studyDaySummaries[studyDay]
    }

#if DEBUG
    func setDemoStudyDaySummaries(_ summaries: [StudyDaySummary]) {
        studyDaySummaries = Dictionary(uniqueKeysWithValues: summaries.map { ($0.studyDay, $0) })
    }

    func setDemoConfirmedWakeupDate(_ date: Date) {
        dateOfLastConfirmedWakeup = date
    }

    func setDemoStudyDaysToFinishOnWakeup(_ studyDays: [Int]) {
        studyDaysToFinishOnWakeup = studyDays
    }
#endif

    func hasRemainingSamplesForCurrentDay() -> Bool {
        if hasEveningSample && !isEveningScanned {
            return true
        }

        return timedAlarms.contains { !$0.isScanned }
    }
    
    func wakeupAlarmSelectionTime() -> Date {
        pendingWakeupNotificationTimes.first ?? getInitialAlarm().time
    }

    func updateWakeupAlarmSelection(time: Date) {
        if Calendar.current.isDate(dateOfLastInitialAlarm, inSameDayAs: Date()) {
            scheduleAlarmNotificationsWithoutInitial(selectedFutureWakeupTime: time)
        } else {
            updateAlarmTime(time: time)
        }
    }

    func isWakeupConfirmedToday() -> Bool {
        Calendar.current.isDate(dateOfLastConfirmedWakeup, inSameDayAs: Date())
    }
    
    func setInitialAlarmActivity(isActive: Bool, selectedWakeupTime: Date? = nil) {
        /// called when initial alarm activity is toggled
        setInitialAlarm(alarm: getInitialAlarm().setIsActive(isActive: isActive))
        if isWakeupConfirmedToday() {
            scheduleFutureWakeupNotificationsOnly(
                referenceTime: dateOfLastInitialAlarm,
                selectedTime: selectedWakeupTime ?? wakeupAlarmSelectionTime()
            )
        } else {
            updateAlarmTime(time: selectedWakeupTime ?? getInitialAlarm().time)
        }
    }
    
    func setTimedAlarmActivity(index: Int, isActive: Bool) {
        guard timedAlarms.indices.contains(index) else {
            return
        }
        guard !isActive || !timedAlarms[index].isScanned else {
            return
        }
        let currentStudyDay = studyDayCounter == 0 ? 1 : studyDayCounter
        timedAlarms[index] = timedAlarms[index].setIsActive(isActive: isActive)
        if !isActive {
            NotificationManager.instance.cancelNotificationsById(alarmId: timedAlarms[index].id, studyDay: currentStudyDay)
        } else {
            scheduleAlarmWithBackupNotifications(
                timedAlarms[index],
                salivaId: "\(startSample + timedAlarms[index].id)",
                studyDay: currentStudyDay
            )
        }
    }
    
    func setUpcomingAlarmTriggered() {
        if shouldFinishPreviousDayOnWakeupConfirmation() {
            return
        }

        if initialAlarm.isActive && !initialAlarm.isTriggered && !Calendar.current.isDate(dateOfLastInitialAlarm, inSameDayAs: Date()) {
            setInitialAlarmTriggered()
            _ = triggerWakeupSampleIfNeeded()
            return
        }

        if let alarm = getNextUpcomingAlarm() {
            // make sure study counter is only incremented once
            if alarm.isTriggered {
                return
            }
            modifyAlarmById(alarm: alarm.setTriggered())
        }
    }
    
    func setCurrentAlarmScanned(alarmId: Int? = nil) {
        var alarm: Alarm?
        didCompleteLastScheduledSample = false
        hasPendingDayReset = false
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
            // cancel this sample's remaining backup notifications for the active study day
            NotificationManager.instance.cancelNotificationsById(
                alarmId: alarm!.id,
                studyDay: studyDayCounter == 0 ? 1 : studyDayCounter
            )
        }

        let dayFinished = isDayFinished()
        if dayFinished {
            didCompleteLastScheduledSample = true
            markDayFinished(reason: .completedAllSamples)
        }

        if dayFinished && !isStudyFinished(){
            hasPendingDayReset = true
        }
    }
    
    func resetAlarmData() {
        /// called after a day is finished
        hasPendingDayReset = false
        isEveningScanned = false
        cancelEveningReminder(clearStoredSelection: false)
        pendingWakeupNotificationTimes = []
        shouldFinishPreviousDayOnWakeup = false
        studyDaysToFinishOnWakeup = []
        setInitialAlarm(
            alarm: Alarm(
                id: AlarmConstants.initialAlarmId,
                isActive: initialAlarm.isActive,
                isScanned: false,
                isTriggered: false,
                time: initialAlarm.time
            )
        )
        // schedule alarms for the next day after all scans for one day were finished
        for alarm in timedAlarms {
            modifyAlarmById(alarm: Alarm(id: alarm.id, isActive: true, isScanned: false, isTriggered: false, time: alarm.time))
        }
        updateAlarmTime(time: getInitialAlarm().time)
    }

    @discardableResult
    func finishCurrentStudyDay() -> Bool {
        guard studyDayCounter > 0, hasRemainingSamplesForCurrentDay() else {
            return false
        }

        NotificationManager.instance.cancelAllNotifications()
        let timedAlarmsSnapshot = timedAlarms
        let isEveningScannedSnapshot = isEveningScanned
        let eveningTimeSnapshot = eveningReminderTime ?? lastEveningReminderSelection
        isEveningScanned = true
        cancelEveningReminder(clearStoredSelection: false)

        timedAlarms = timedAlarms.map { alarm in
            guard !alarm.isScanned else {
                return alarm
            }

            return Alarm(
                id: alarm.id,
                isActive: false,
                isScanned: true,
                isTriggered: alarm.isTriggered,
                time: alarm.time
            )
        }

        didCompleteLastScheduledSample = true
        markDayFinished(
            reason: .userFinishedDay,
            timedAlarmsSnapshot: timedAlarmsSnapshot,
            isEveningScannedSnapshot: isEveningScannedSnapshot,
            eveningTimeSnapshot: eveningTimeSnapshot
        )

        if studyDayCounter < numStudyDays {
            resetAlarmData()
        }

        return true
    }

    func shouldResolvePreviousStudyDayBeforeScanning() -> Bool {
        studyDayCounter > 0
            && hasReachedStudyDayCutoff()
            && hasRemainingSamplesForCurrentDay()
    }

    func hasReachedStudyDayCutoff(referenceTime: Date = Date()) -> Bool {
        guard studyDayCounter > 0, dateOfLastInitialAlarm != Date.distantPast else {
            return false
        }

        let cutoffInterval = TimeInterval(AlarmConstants.studyDayCutoffHours * 60 * 60)
        return referenceTime.timeIntervalSince(dateOfLastInitialAlarm) >= cutoffInterval
    }

    func lastMissingSampleIdForCurrentStudyDay() -> Int? {
        if hasEveningSample && !isEveningScanned {
            return AlarmConstants.eveningAlarmId
        }

        return timedAlarms
            .filter { !$0.isScanned }
            .max { $0.time < $1.time }?
            .id
    }

    @discardableResult
    func finishPreviousStudyDayAfterLateScan(scannedSampleId: Int? = nil) -> Bool {
        guard studyDayCounter > 0 else {
            return false
        }

        let shouldClosePreviousStudyDay = scannedSampleId == AlarmConstants.eveningAlarmId
            || !hasRemainingSamplesForCurrentDay()
            || hasReachedStudyDayCutoff()

        guard shouldClosePreviousStudyDay else {
            return false
        }

        if hasRemainingSamplesForCurrentDay() {
            NotificationManager.instance.cancelAllNotifications()
            let timedAlarmsSnapshot = timedAlarms
            let isEveningScannedSnapshot = isEveningScanned
            let eveningTimeSnapshot = eveningReminderTime ?? lastEveningReminderSelection
            isEveningScanned = true
            cancelEveningReminder(clearStoredSelection: false)

            timedAlarms = timedAlarms.map { alarm in
                guard !alarm.isScanned else {
                    return alarm
                }

                return Alarm(
                    id: alarm.id,
                    isActive: false,
                    isScanned: true,
                    isTriggered: alarm.isTriggered,
                    time: alarm.time
                )
            }

            markDayFinished(
                reason: .completedPreviousDayAfterLateScan,
                timedAlarmsSnapshot: timedAlarmsSnapshot,
                isEveningScannedSnapshot: isEveningScannedSnapshot,
                eveningTimeSnapshot: eveningTimeSnapshot
            )
        }

        didCompleteLastScheduledSample = true

        if studyDayCounter < numStudyDays {
            resetAlarmData()
        } else {
            hasPendingDayReset = false
        }

        return true
    }

    @discardableResult
    func finishPreviousStudyDayAndStartTodayForScan(at wakeupTime: Date = Date()) -> Bool {
        guard shouldResolvePreviousStudyDayBeforeScanning() else {
            return false
        }

        NotificationManager.instance.cancelAllNotifications()
        let timedAlarmsSnapshot = timedAlarms
        let isEveningScannedSnapshot = isEveningScanned
        let eveningTimeSnapshot = eveningReminderTime ?? lastEveningReminderSelection
        isEveningScanned = true
        cancelEveningReminder(clearStoredSelection: false)

        timedAlarms = timedAlarms.map { alarm in
            Alarm(
                id: alarm.id,
                isActive: false,
                isScanned: true,
                isTriggered: alarm.isTriggered,
                time: alarm.time
            )
        }

        markDayFinished(
            reason: .selectedCurrentDateForScan,
            timedAlarmsSnapshot: timedAlarmsSnapshot,
            isEveningScannedSnapshot: isEveningScannedSnapshot,
            eveningTimeSnapshot: eveningTimeSnapshot
        )

        guard studyDayCounter < numStudyDays else {
            didCompleteLastScheduledSample = true
            hasPendingDayReset = false
            return true
        }

        resetAlarmData()
        confirmWakeup(at: wakeupTime)
        return true
    }

    @discardableResult
    func finishPendingPreviousStudyDayAndKeepWakeupPending() -> Bool {
        guard finishPreviousDayForPendingWakeupIfNeeded() else {
            return false
        }

        timedAlarms = alarmTimes(for: initialAlarm.time).enumerated().map { offset, time in
            Alarm(
                id: offset,
                isActive: initialAlarm.isActive,
                isScanned: false,
                isTriggered: false,
                time: time
            )
        }
        isEveningScanned = false
        eveningReminderTime = nil
        return true
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
            newTime = getNextDateTimeOccurrsAfterToday(time: time)
        } else {
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
        alarmTimes(for: getInitialAlarm().time)
    }

    private func alarmTimes(for initialTime: Date) -> [Date] {
        var updatedAlarmTimes = [Date]()
        updatedAlarmTimes.append(contentsOf: intervalAlarmTimes(for: initialTime))
        updatedAlarmTimes.append(contentsOf: fixedAlarmTimes(for: initialTime))
        // bring times in correct chronological order
        updatedAlarmTimes.sort()
        return updatedAlarmTimes
    }

    private func intervalAlarmTimes(for initialTime: Date) -> [Date] {
        var previousAlarmTime = initialTime
        return timeIntervals.map { interval in
            let newAlarmTime = previousAlarmTime.addingTimeInterval(TimeInterval(interval * 60))
            previousAlarmTime = newAlarmTime
            return newAlarmTime
        }
    }

    private func fixedAlarmTimes(for initialTime: Date) -> [Date] {
        var updatedAlarmTimes = [Date]()
        for time in fixedTimes {
            // add times of fixed alarms
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: initialTime)
            dc.hour = time.hour
            dc.minute = time.minute
            if let fixedTime = Calendar.current.date(from: dc) {
                updatedAlarmTimes.append(fixedTime)
            }
        }
        updatedAlarmTimes.sort()
        return updatedAlarmTimes
    }

    func shouldFinishPreviousDayOnWakeupConfirmation() -> Bool {
        !studyDaysToFinishOnWakeup.isEmpty || (shouldFinishPreviousDayOnWakeup && hasRemainingSamplesForCurrentDay())
    }

    func pendingUnfinishedStudyDayForWakeupConfirmation() -> Int? {
        guard shouldFinishPreviousDayOnWakeupConfirmation() else {
            return nil
        }

        if let firstPendingStudyDay = studyDaysToFinishOnWakeup.sorted().first {
            return firstPendingStudyDay
        }

        let previousStudyDay = studyDayCounter - 1
        return previousStudyDay > 0 ? previousStudyDay : nil
    }

    func pendingUnfinishedStudyDayStartTimeForWakeupConfirmation() -> Date? {
        guard let pendingStudyDay = pendingUnfinishedStudyDayForWakeupConfirmation() else {
            return nil
        }

        if let summary = studyDaySummary(for: pendingStudyDay),
           let firstSampleTime = summary.timedAlarms.min(by: { $0.time < $1.time })?.time {
            return firstSampleTime
        }

        return timedAlarms.min(by: { $0.time < $1.time })?.time ?? dateOfLastInitialAlarm
    }

    private func processPendingWakeupNotificationIfNeeded(now: Date) -> Bool {
        let dueWakeups = pendingWakeupNotificationTimes
            .filter { $0 <= now && !Calendar.current.isDate(dateOfLastInitialAlarm, inSameDayAs: $0) }
            .sorted()

        guard let latestDueWakeup = dueWakeups.last else {
            return false
        }

        let targetStudyDay = min(studyDayCounter + dueWakeups.count, numStudyDays)
        if lastFinishedStudyDayCounter < targetStudyDay - 1 {
            studyDaysToFinishOnWakeup = Array((lastFinishedStudyDayCounter + 1)..<targetStudyDay)
        } else {
            studyDaysToFinishOnWakeup = []
        }
        pendingWakeupNotificationTimes.removeAll { $0 <= latestDueWakeup }
        setInitialAlarm(
            alarm: Alarm(
                id: AlarmConstants.initialAlarmId,
                isActive: true,
                isScanned: false,
                isTriggered: false,
                time: latestDueWakeup
            )
        )
        initialAlarm = initialAlarm.setTriggered()
        dateOfLastInitialAlarm = latestDueWakeup
        studyDayCounter = targetStudyDay
        return true
    }

    private func finishPreviousDayForPendingWakeupIfNeeded() -> Bool {
        guard shouldFinishPreviousDayOnWakeupConfirmation() else {
            return false
        }

        let daysToFinish = studyDaysToFinishOnWakeup.isEmpty ? [max(studyDayCounter - 1, 0)] : studyDaysToFinishOnWakeup
        NotificationManager.instance.cancelNotificationsById(alarmId: AlarmConstants.eveningAlarmId)
        let timedAlarmsSnapshot = timedAlarms
        let isEveningScannedSnapshot = isEveningScanned
        let eveningTimeSnapshot = eveningReminderTime ?? lastEveningReminderSelection
        isEveningScanned = true
        cancelEveningReminder(clearStoredSelection: false)

        timedAlarms = timedAlarms.map { alarm in
            Alarm(
                id: alarm.id,
                isActive: false,
                isScanned: true,
                isTriggered: alarm.isTriggered,
                time: alarm.time
            )
        }
        for studyDay in daysToFinish where studyDay > 0 {
            let missedTimedAlarms = timedAlarmsSnapshot.map { alarm in
                Alarm(
                    id: alarm.id,
                    isActive: false,
                    isScanned: alarm.isScanned,
                    isTriggered: alarm.isTriggered,
                    time: alarm.time
                )
            }
            markDayFinished(
                reason: .recoveredOnWakeup,
                studyDay: studyDay,
                timedAlarmsSnapshot: missedTimedAlarms,
                isEveningScannedSnapshot: isEveningScannedSnapshot,
                eveningTimeSnapshot: eveningTimeSnapshot
            )
        }

        hasPendingDayReset = false
        didCompleteLastScheduledSample = false
        studyDaysToFinishOnWakeup = []
        shouldFinishPreviousDayOnWakeup = false
        for alarm in timedAlarms {
            modifyAlarmById(
                alarm: Alarm(
                    id: alarm.id,
                    isActive: true,
                    isScanned: false,
                    isTriggered: false,
                    time: alarm.time
                )
            )
        }
        return true
    }

    private func rebaseTimedAlarmsAfterWakeupConfirmation(now: Date) {
        timedAlarms = timedAlarms.map { alarm in
            guard !alarm.isScanned else {
                return alarm
            }

            return Alarm(
                id: alarm.id,
                isActive: true,
                isScanned: false,
                isTriggered: alarm.time <= now,
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
        let now = Date()

        if processPendingWakeupNotificationIfNeeded(now: now) {
            var msg = [String: Any]()
            msg[LoggerConstants.loggerExtraAlarmId] = initialAlarm.id
            Logger.instance.log(tag: LoggerConstants.loggerActionAlarmReceived, message: msg)
        } else if initialAlarm.isActive && !initialAlarm.isTriggered && initialAlarm.time <= now {
            setInitialAlarmTriggered()
            _ = triggerWakeupSampleIfNeeded()
            var msg = [String: Any]()
            msg[LoggerConstants.loggerExtraAlarmId] = initialAlarm.id
            Logger.instance.log(tag: LoggerConstants.loggerActionAlarmReceived, message: msg)
        }

        // check if any unscanned alarms are in the past
        for alarm in timedAlarms {
            if alarm.isActive && !alarm.isScanned && !alarm.isTriggered && alarm.time <= now {
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

        cancelEveningReminder(clearStoredSelection: false)
        eveningReminderTime = scheduledTime
        lastEveningReminderSelection = scheduledTime
        scheduleAlarmWithBackupNotifications(eveningAlarm, salivaId: "\(eveningSampleId)")
        logAlarmScheduled(eveningAlarm)
        shouldPromptForEveningReminderSetup = false
    }

    func cancelEveningReminder(clearStoredSelection: Bool = false) {
        eveningReminderTime = nil
        if clearStoredSelection {
            lastEveningReminderSelection = nil
        }
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

    func saveDateOfLastConfirmedWakeup() {
        if let encodedDateOfLastConfirmedWakeup = try? JSONEncoder().encode(dateOfLastConfirmedWakeup) {
            UserDefaults.standard.set(encodedDateOfLastConfirmedWakeup, forKey: dateOfLastConfirmedWakeupKey)
        }
    }
    
    func scheduleAlarmNotifications() {
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // do not schedule new notifications if alarm toggle is set inactive
        if !getInitialAlarm().isActive {
            return
        }
        scheduleAlarmWithBackupNotifications(getInitialAlarm(), salivaId: nil, studyDay: studyDayCounter == 0 ? 1 : studyDayCounter)
        for alarm in fixedSampleAlarms(forStudyDay: studyDayCounter == 0 ? 1 : studyDayCounter, wakeupTime: getInitialAlarm().time) {
            scheduleAlarmWithBackupNotifications(alarm, salivaId: "\(startSample + alarm.id)", studyDay: studyDayCounter == 0 ? 1 : studyDayCounter)
        }
        scheduleFutureStudyDayNotifications(referenceTime: getInitialAlarm().time)
    }
    
    func scheduleAlarmNotificationsWithoutInitial(selectedFutureWakeupTime: Date? = nil) {
        // cancel all previous alarms
        NotificationManager.instance.cancelAllNotifications()
        // schedule notifications for all sample reminders, but not the wakeup alarm
        for alarm in timedAlarms {
            scheduleAlarmWithBackupNotifications(alarm, salivaId: "\(startSample + alarm.id)", studyDay: studyDayCounter)
            logAlarmScheduled(alarm)
        }
        scheduleFutureStudyDayNotifications(referenceTime: getInitialAlarm().time, selectedTime: selectedFutureWakeupTime)
    }
    
    func scheduleAlarmWithBackupNotifications(_ alarm: Alarm, salivaId: String?, studyDay: Int? = nil) {
        guard alarm.isActive else {
            return
        }

        for i in 0..<NotificationConstants.numberOfSubsequentNotifications {
            // calculate notification time
            guard let notificationTime = alarm.getCurrentAlarmTimePlusInterval(numMinutes: i * NotificationConstants.minutesBetweenNotifications) else {
                return
            }
            NotificationManager.instance.scheduleCalendarBasedNotification(
                id: notificationIdentifier(alarmId: alarm.id, backupIndex: i, studyDay: studyDay),
                salivaId: salivaId,
                date: notificationTime
            )
        }
    }

    private func scheduleFutureStudyDayNotifications(referenceTime: Date, selectedTime: Date? = nil) {
        guard initialAlarm.isActive, studyDayCounter < numStudyDays else {
            pendingWakeupNotificationTimes = []
            return
        }

        let calendar = Calendar.current
        let configuredWakeupTime = selectedTime ?? initialAlarm.time
        let wakeupComponents = calendar.dateComponents([.hour, .minute, .second], from: configuredWakeupTime)
        var scheduledWakeups: [Date] = []
        let currentStudyDay = studyDayCounter == 0 ? 1 : studyDayCounter

        for studyDay in (currentStudyDay + 1)...numStudyDays {
            let dayOffset = studyDay - currentStudyDay
            guard let nextDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceTime) else {
                continue
            }

            var nextWakeupComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
            nextWakeupComponents.hour = wakeupComponents.hour
            nextWakeupComponents.minute = wakeupComponents.minute
            nextWakeupComponents.second = wakeupComponents.second

            guard let wakeupTime = calendar.date(from: nextWakeupComponents) else {
                continue
            }

            scheduledWakeups.append(wakeupTime)
            scheduleAlarmWithBackupNotifications(
                Alarm(id: AlarmConstants.initialAlarmId, isActive: true, time: wakeupTime),
                salivaId: nil,
                studyDay: studyDay
            )

            for alarm in fixedSampleAlarms(forStudyDay: studyDay, wakeupTime: wakeupTime) {
                scheduleAlarmWithBackupNotifications(
                    alarm,
                    salivaId: "\(startSample + alarm.id)",
                    studyDay: studyDay
                )
            }
        }

        pendingWakeupNotificationTimes = scheduledWakeups
    }

    private func scheduleFutureWakeupNotificationsOnly(referenceTime: Date, selectedTime: Date? = nil) {
        NotificationManager.instance.cancelNotificationsById(alarmId: AlarmConstants.initialAlarmId)

        guard initialAlarm.isActive, studyDayCounter < numStudyDays else {
            pendingWakeupNotificationTimes = []
            return
        }

        let calendar = Calendar.current
        let configuredWakeupTime = selectedTime ?? initialAlarm.time
        let wakeupComponents = calendar.dateComponents([.hour, .minute, .second], from: configuredWakeupTime)
        var scheduledWakeups: [Date] = []
        let currentStudyDay = studyDayCounter == 0 ? 1 : studyDayCounter

        for studyDay in (currentStudyDay + 1)...numStudyDays {
            let dayOffset = studyDay - currentStudyDay
            guard let nextDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceTime) else {
                continue
            }

            var nextWakeupComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
            nextWakeupComponents.hour = wakeupComponents.hour
            nextWakeupComponents.minute = wakeupComponents.minute
            nextWakeupComponents.second = wakeupComponents.second

            guard let wakeupTime = calendar.date(from: nextWakeupComponents) else {
                continue
            }

            scheduledWakeups.append(wakeupTime)
            scheduleAlarmWithBackupNotifications(
                Alarm(id: AlarmConstants.initialAlarmId, isActive: true, time: wakeupTime),
                salivaId: nil,
                studyDay: studyDay
            )
        }

        pendingWakeupNotificationTimes = scheduledWakeups
    }

    private func fixedSampleAlarms(forStudyDay studyDay: Int, wakeupTime: Date) -> [Alarm] {
        let allAlarmTimes = alarmTimes(for: wakeupTime)
        let fixedTimes = Set(fixedAlarmTimes(for: wakeupTime))
        let currentStudyDay = studyDayCounter == 0 ? 1 : studyDayCounter

        return allAlarmTimes.enumerated().compactMap { offset, alarmTime in
            guard fixedTimes.contains(alarmTime) else {
                return nil
            }

            let currentAlarm = studyDay == currentStudyDay ? timedAlarms.first { $0.id == offset } : nil
            return Alarm(
                id: offset,
                isActive: currentAlarm?.isActive ?? true,
                isScanned: currentAlarm?.isScanned ?? false,
                isTriggered: currentAlarm?.isTriggered ?? false,
                time: alarmTime
            )
        }
    }

    func scheduledTimedAlarms(forStudyDay studyDay: Int) -> [Alarm] {
        guard studyDay > 0 else {
            return timedAlarms
        }

        if studyDay == studyDayCounter && pendingUnfinishedStudyDayForWakeupConfirmation() == nil {
            return timedAlarms
        }

        let calendar = Calendar.current
        let referenceStudyDay = studyDayCounter == 0 ? 1 : studyDayCounter
        let referenceWakeupTime = initialAlarm.time
        let dayOffset = studyDay - referenceStudyDay
        guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceWakeupTime) else {
            return []
        }

        let wakeupComponents = calendar.dateComponents([.hour, .minute, .second], from: referenceWakeupTime)
        var targetWakeupComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
        targetWakeupComponents.hour = wakeupComponents.hour
        targetWakeupComponents.minute = wakeupComponents.minute
        targetWakeupComponents.second = wakeupComponents.second

        guard let wakeupTime = calendar.date(from: targetWakeupComponents) else {
            return []
        }

        return alarmTimes(for: wakeupTime).enumerated().map { offset, time in
            Alarm(id: offset, isActive: true, isScanned: false, isTriggered: false, time: time)
        }
    }

    private func notificationIdentifier(alarmId: Int, backupIndex: Int, studyDay: Int?) -> String {
        guard let studyDay else {
            return "\(alarmId)_\(backupIndex)"
        }

        return "\(alarmId)_\(backupIndex)_day\(studyDay)"
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
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraAlarmId] = alarm.id
        msg[LoggerConstants.loggerExtraAlarmTimestamp] = getUnixTimeMillisFromDate(alarm.time)
        msg[LoggerConstants.loggerTranslatedTimestamp] = formatDateForLogs(alarm.time)
        Logger.instance.log(tag: LoggerConstants.loggerActionAlarmSet, message: msg)
    }
    
    func isStudyFinished() -> Bool {
        let isFinished = isDayFinished() && studyDayCounter == numStudyDays
        return isFinished
    }
    
    func resetAlarmDataForNewUser() {
        initialAlarm = defaultInitialAlarm()
        timedAlarms = []
        isEveningScanned = false
        studyDayCounter = 0
        lastFinishedStudyDayCounter = 0
        isDarkModeOn = nil
        eveningReminderTime = nil
        lastEveningReminderSelection = nil
        pendingWakeupNotificationTimes = []
        shouldFinishPreviousDayOnWakeup = false
        studyDaysToFinishOnWakeup = []
        shouldPromptForEveningReminderSetup = false
        dateOfLastInitialAlarm = Date.distantPast
        dateOfLastConfirmedWakeup = Date.distantPast
        studyDaySummaries = [:]
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

    private func saveLastEveningReminderSelection() {
        if let lastEveningReminderSelection {
            if let encodedLastEveningReminderSelection = try? JSONEncoder().encode(lastEveningReminderSelection) {
                UserDefaults.standard.set(encodedLastEveningReminderSelection, forKey: lastEveningReminderSelectionKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: lastEveningReminderSelectionKey)
        }
    }

    private func savePendingWakeupNotificationTimes() {
        if pendingWakeupNotificationTimes.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingWakeupNotificationTimesKey)
            UserDefaults.standard.removeObject(forKey: pendingWakeupNotificationTimeKey)
        } else {
            if let encodedPendingWakeupNotificationTimes = try? JSONEncoder().encode(pendingWakeupNotificationTimes) {
                UserDefaults.standard.set(encodedPendingWakeupNotificationTimes, forKey: pendingWakeupNotificationTimesKey)
            }
        }
    }

    private func saveStudyDaySummaries() {
        if studyDaySummaries.isEmpty {
            UserDefaults.standard.removeObject(forKey: studyDaySummariesKey)
        } else if let encodedSummaries = try? JSONEncoder().encode(Array(studyDaySummaries.values)) {
            UserDefaults.standard.set(encodedSummaries, forKey: studyDaySummariesKey)
        }
    }
}
