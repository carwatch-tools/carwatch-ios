import SwiftUI
import AlertToast
import UIKit

enum ScannerPresentationSource {
    case wakeup
    case schedule
    case notification
}

private enum StudyDayChoiceContext {
    case openingAfterCutoff
    case scanningAfterCutoff
}

struct OngoingStudyView: View {
    @StateObject var alarmVM: AlarmViewModel
    
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State var isBarcodeScannerPresented = false
    @State var currentAlarmId: Int? = nil
    @State var initialAlarmTime: Date = getDateTomorrowMorning()
    @State private var pendingWakeupConfirmationTime: Date? = nil
    
    @State private var selectedTab = 0
    @State private var scannerSource: ScannerPresentationSource? = nil
    
    @State private var showAppInfoDialog = false
    @State private var appVersion: String? = nil
    @State private var showToast: Bool = false
    @State private var toastType: MenuConstants.ToastType = .clickToKill
    @State private var killButtonClickCount: Int = 0
    @State private var showScheduleCompletionAlert: Bool = false
    @State private var scheduleCompletionTitle: String = ""
    @State private var scheduleCompletionMessage: String = ""
    @State private var showDueSampleAlert: Bool = false
    @State private var dueSampleAlertTitle: String = ""
    @State private var showWakeupRequiredBeforeSampleAlert: Bool = false
    @State private var showPreviousDayUnfinishedWakeupAlert: Bool = false
    @State private var showSampleDayChoiceAlert: Bool = false
    @State private var studyDayChoiceContext: StudyDayChoiceContext = .scanningAfterCutoff
    @State private var didPromptForCutoffChoice = false
    @State private var pendingForegroundNotificationIdentifier: String? = nil
    @State private var hasAppeared = false
    @State private var pendingBedtimeTabAfterEveningReminder = false
    @State private var isDeferringScannerForDayChoice = false
    @State private var skipDayChoiceForNextScannerPresentation = false
    @State private var shouldFinishPreviousDayAfterLateScan = false
    @State private var didFinishPreviousDayAfterLateScan = false
    @State private var finishedStudyDayToDisplay: Int? = nil

    private var preferredColorScheme: ColorScheme? {
        guard let isDarkModeOn = alarmVM.isDarkModeOn else {
            return nil
        }
        return isDarkModeOn ? .dark : .light
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.systemBlue
        ]

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.titleTextAttributes = normalAttributes
            itemAppearance.selected.titleTextAttributes = selectedAttributes
            itemAppearance.normal.iconColor = UIColor.secondaryLabel
            itemAppearance.selected.iconColor = UIColor.systemBlue
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    init(alarmViewModel: AlarmViewModel? = nil) {
        _alarmVM = StateObject(wrappedValue: alarmViewModel ?? AlarmViewModel())
    }
    
    var body: some View {
        if permissionDataVM.permissionData.cameraPermissionGranted {
            NavigationStack{
                TabView(selection: $selectedTab){
                    WakeupView(
                        initialAlarmTime: $initialAlarmTime,
                        isScannerPresented: $isBarcodeScannerPresented,
                        scannerSource: $scannerSource,
                        pendingWakeupConfirmationTime: $pendingWakeupConfirmationTime,
                        showPreviousDayUnfinishedAlert: $showPreviousDayUnfinishedWakeupAlert,
                        onDelayedSampleAcknowledged: {
                            selectedTab = 1
                        }
                    )
                        .tabItem {
                            tabItemLabel(title: "Wakeup", systemImage: "sun.max")
                        }.tag(0)
                        .padding(StyleConstants.edgePadding)
                        .environmentObject(alarmVM)
                    AlarmView(
                        initialAlarmTime: $initialAlarmTime,
                        isScannerPresented: $isBarcodeScannerPresented,
                        currentAlarmId: $currentAlarmId,
                        scannerSource: $scannerSource,
                        pendingWakeupConfirmationTime: $pendingWakeupConfirmationTime,
                        finishedStudyDayToDisplay: $finishedStudyDayToDisplay
                    )
                        .tabItem {
                            tabItemLabel(title: "Schedule", systemImage: "alarm")
                        }.tag(1)
                        .environmentObject(alarmVM)
                    BedtimeView(
                        isScannerPresented: $isBarcodeScannerPresented,
                        alarmId: $currentAlarmId,
                        scannerSource: $scannerSource,
                        selectedTab: $selectedTab,
                        finishedStudyDayToDisplay: $finishedStudyDayToDisplay
                    )
                        .tabItem {
                            tabItemLabel(title: "Bedtime", systemImage: "bed.double")
                        }.tag(2)
                        .environmentObject(alarmVM)
                }
                .navigationBarTitle(tabTitle)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        MainViewToolbarMenu(showAppInfoDialog: $showAppInfoDialog, appVersion: $appVersion, showToast: $showToast, killButtonClickCount: $killButtonClickCount, toastType: $toastType, selectedTab: $selectedTab, finishedStudyDayToDisplay: $finishedStudyDayToDisplay)
                            .environmentObject(alarmVM)
                    }
                }
                .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
                    var toastMsg = ""
                    switch toastType {
                    case .clickToKill:
                        let clicksLeft = MenuConstants.killButtonClickCountActivate - killButtonClickCount
                        toastMsg = String(
                            format: localizedAppString("Click %lld more times to kill all reminders!"),
                            Int64(clicksLeft)
                        )
                    case .killSuccess:
                        toastMsg = localizedAppString("All reminders were deactivated!")
                    case .zipLogsFailed:
                        toastMsg = localizedAppString("Generating the logs failed.\nPlease try again later!")
                    case .studyDayFinished:
                        toastMsg = localizedAppString("The current study day has been finished.\nPlease check your wakeup alarm for tomorrow.")
                    }
                    let color = Color(UIColor.secondarySystemBackground)
                    return AlertToast(displayMode: .banner(.slide), type: .regular, title: toastMsg, style: .style(backgroundColor: color))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .notificationTapped)) { _ in
                updateAlarmStatus()
                checkScannerStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .alarmKitOpenActionTapped)) { _ in
                updateAlarmStatus()
                checkScannerStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .foregroundNotificationReceived)) { notification in
                updateAlarmStatus()
                handleForegroundNotification(notification)
            }
            .onForeground {
                updateAlarmStatus()
                checkScannerStatus()
                presentCutoffStudyDayChoiceIfNeeded()
            }
            .onAppear {
                configureTabBarAppearance()
                initializeStudyData()
                updateTimedAlarms()
                checkScannerStatus()
                presentCutoffStudyDayChoiceIfNeeded()
                if !hasAppeared {
                    hasAppeared = true
                    announceCurrentTab()
                }
            }
            .onChange(of: selectedTab) { _ in
                announceCurrentTab()
            }
            .onChange(of: isBarcodeScannerPresented) { isPresented in
                if isPresented {
                    if skipDayChoiceForNextScannerPresentation {
                        skipDayChoiceForNextScannerPresentation = false
                        return
                    }

                    if shouldAskWhichStudyDateThisScanBelongsTo() {
                        isDeferringScannerForDayChoice = true
                        isBarcodeScannerPresented = false
                        studyDayChoiceContext = .scanningAfterCutoff
                        showSampleDayChoiceAlert = true
                    }

                    return
                }

                if isDeferringScannerForDayChoice {
                    isDeferringScannerForDayChoice = false
                    return
                }

                let didScanSelectedSample: Bool = {
                    guard let currentAlarmId else {
                        return false
                    }

                    if currentAlarmId == AlarmConstants.eveningAlarmId {
                        return alarmVM.isEveningScanned
                    }

                    guard let scannedAlarm = alarmVM.getAlarmById(alarmId: currentAlarmId) else {
                        return false
                    }

                    return scannedAlarm.isScanned
                }()
                let scannedNonEveningSample = didScanSelectedSample && currentAlarmId != AlarmConstants.eveningAlarmId

                if shouldFinishPreviousDayAfterLateScan {
                    shouldFinishPreviousDayAfterLateScan = false
                    if didScanSelectedSample {
                        didFinishPreviousDayAfterLateScan = alarmVM.finishPreviousStudyDayAfterLateScan(scannedSampleId: currentAlarmId)
                    }
                }

                if scannerSource != nil && alarmVM.didCompleteLastScheduledSample {
                    if didFinishPreviousDayAfterLateScan && !alarmVM.isStudyFinished() {
                        pendingBedtimeTabAfterEveningReminder = false
                        selectedTab = 0
                        scheduleCompletionTitle = localizedAppString("Previous Study Day Finished")
                        scheduleCompletionMessage = localizedAppString("The previous study day has been finished. Please continue with today's wakeup when you are ready.")
                    } else if alarmVM.hasEveningSample && !alarmVM.isEveningScanned {
                        if alarmVM.eveningReminderTime == nil {
                            pendingBedtimeTabAfterEveningReminder = true
                            alarmVM.shouldPromptForEveningReminderSetup = true
                        } else {
                            pendingBedtimeTabAfterEveningReminder = false
                            selectedTab = 2
                        }
                        scheduleCompletionTitle = localizedAppString("Samples Recorded")
                        scheduleCompletionMessage = localizedAppString("You've recorded all samples for the day, but you are still required to record an evening sample tonight right before you go to bed.\nPlease set a reminder below.\nSee you later!")
                    } else if alarmVM.isStudyFinished() {
                        pendingBedtimeTabAfterEveningReminder = false
                        selectedTab = 2
                        scheduleCompletionTitle = localizedAppString("Study Finished")
                        scheduleCompletionMessage = localizedAppString("This was your last sample. Thank you for participating in the study! Please export your logs and send them to your study contact email.")
                    } else {
                        pendingBedtimeTabAfterEveningReminder = false
                        selectedTab = scannerSource == .wakeup ? 1 : 2
                        scheduleCompletionTitle = localizedAppString("Samples Recorded")
                        scheduleCompletionMessage = localizedAppString("You've recorded the last sample for today.\nPlease record bedtime before going to sleep, and check your wakeup alarm for tomorrow.")
                    }
                    showScheduleCompletionAlert = true
                } else if scannedNonEveningSample {
                    selectedTab = 1
                }

                alarmVM.didCompleteLastScheduledSample = false
                didFinishPreviousDayAfterLateScan = false
                currentAlarmId = nil
                scannerSource = nil
                pendingWakeupConfirmationTime = nil
                presentPendingDueSampleAlertIfNeeded()
            }
            .sheet(isPresented: $isBarcodeScannerPresented) {
                ScannerView(
                    isPresented: $isBarcodeScannerPresented,
                    alarmId: $currentAlarmId,
                    pendingWakeupConfirmationTime: $pendingWakeupConfirmationTime,
                    codeType: ScannerConstants.CodeType.ean8
                )
                    .interactiveDismissDisabled()
                    .environmentObject(alarmVM)
            }
            .fullScreenCover(isPresented: $sessionVM.isInStudyTutorialPresented, onDismiss: {
                if let returnTab = sessionVM.consumeTutorialReturnTab() {
                    selectedTab = returnTab
                }
            }) {
                TutorialView(isPresentedFromOngoingStudy: true)
                    .environmentObject(sessionVM)
            }
            .alert(scheduleCompletionTitle, isPresented: $showScheduleCompletionAlert) {
                Button(localizedAppString("OK")) {
                    if alarmVM.hasPendingDayReset {
                        alarmVM.resetAlarmData()
                    }
                }
            } message: {
                Text(scheduleCompletionMessage)
            }
            .alert(dueSampleAlertTitle, isPresented: $showDueSampleAlert) {
                Button(localizedAppString("Open Scanner")) {
                    if shouldRequireWakeupBeforeSampleScan() {
                        showWakeupRequiredBeforeSampleAlert = true
                    } else {
                        preparePendingWakeupConfirmationIfNeeded()
                        isBarcodeScannerPresented = true
                    }
                }
                Button(localizedAppString("Dismiss"), role: .cancel) {
                    currentAlarmId = nil
                    scannerSource = nil
                    pendingWakeupConfirmationTime = nil
                }
            }
            .alert(localizedAppString("Wakeup not recorded"), isPresented: $showWakeupRequiredBeforeSampleAlert) {
                Button(localizedAppString("Record Wakeup Now")) {
                    if !alarmVM.shouldResolvePreviousStudyDayBeforeScanning() {
                        alarmVM.confirmWakeup(at: Date())
                    }
                    isBarcodeScannerPresented = true
                }
                Button(localizedAppString("Cancel"), role: .cancel) {
                    currentAlarmId = nil
                    scannerSource = nil
                    pendingWakeupConfirmationTime = nil
                }
            } message: {
                Text(localizedAppString("You have not recorded your wakeup yet. Please record wakeup before scanning this sample."))
            }
            .alert(sampleDayChoiceTitle, isPresented: $showSampleDayChoiceAlert) {
                Button(previousStudyDateButtonTitle) {
                    continueWithPreviousStudyDate()
                }
                Button(currentStudyDateButtonTitle) {
                    continueWithCurrentStudyDate()
                }
                Button(localizedAppString("Cancel"), role: .cancel) {
                    currentAlarmId = nil
                    scannerSource = nil
                    pendingWakeupConfirmationTime = nil
                }
            } message: {
                Text(sampleDayChoiceMessage)
            }
            .onChange(of: showScheduleCompletionAlert) { isPresented in
                guard isPresented else {
                    return
                }

                postAccessibilityAnnouncement("\(scheduleCompletionTitle). \(scheduleCompletionMessage)")
            }
            .onChange(of: alarmVM.eveningReminderTime) { newValue in
                if pendingBedtimeTabAfterEveningReminder, newValue != nil {
                    pendingBedtimeTabAfterEveningReminder = false
                    selectedTab = 2
                }
            }
            .preferredColorScheme(preferredColorScheme)
        } else {
            MissingPermissionView(type: PermissionConstants.PermissionType.camera)
        }
    }
    
    private var tabTitle: LocalizedStringKey {
        switch selectedTab {
        case 0: return "Wakeup"
        case 1: return "Schedule"
        case 2: return "Bedtime"
        default: return "Title"
        }
    }

    private var sampleDayChoiceTitle: String {
        switch studyDayChoiceContext {
        case .openingAfterCutoff:
            return localizedAppString("Continue or start a study day?")
        case .scanningAfterCutoff:
            return localizedAppString("Which study day is this sample for?")
        }
    }

    private var sampleDayChoiceMessage: String {
        switch studyDayChoiceContext {
        case .openingAfterCutoff:
            return String(
                format: localizedAppString("The study day that started at %@ still has missing samples. Please choose whether you want to continue the current study day or finish it and start a new study day today, %@."),
                formattedStudyDateTime(unresolvedStudyDayStartTime),
                formattedStudyDate(Date())
            )
        case .scanningAfterCutoff:
            return scanDayChoiceMessage
        }
    }

    private var scanDayChoiceMessage: String {
        let consequenceMessage: String
        if isWakeupSampleConfiguredForTodayChoice() {
            consequenceMessage = localizedAppString("If you choose today, the current time is used as your wakeup time and you will be able to record your wakeup sample.")
        } else {
            consequenceMessage = localizedAppString("If you choose today, the current time is used as your wakeup time.")
        }

        return String(
            format: localizedAppString("The previous study day that started at %@ still has missing samples. Please choose whether this scan belongs to that study day or to today, %@.\n\n%@"),
            formattedStudyDateTime(alarmVM.dateOfLastInitialAlarm),
            formattedStudyDate(Date()),
            consequenceMessage
        )
    }

    private var previousStudyDateButtonTitle: String {
        String(
            format: localizedAppString("Previous day (%@)"),
            formattedStudyDate(unresolvedStudyDayStartTime)
        )
    }

    private var currentStudyDateButtonTitle: String {
        String(
            format: localizedAppString("Today (%@)"),
            formattedStudyDate(Date())
        )
    }

    private func formattedStudyDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedStudyDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var unresolvedStudyDayStartTime: Date {
        alarmVM.pendingUnfinishedStudyDayStartTimeForWakeupConfirmation() ?? alarmVM.dateOfLastInitialAlarm
    }

    private func shouldAskWhichStudyDateThisScanBelongsTo() -> Bool {
        alarmVM.shouldResolvePreviousStudyDayBeforeScanning()
    }

    private func presentCutoffStudyDayChoiceIfNeeded() {
        let shouldPresentChoice = alarmVM.shouldResolvePreviousStudyDayBeforeScanning()
            || alarmVM.shouldFinishPreviousDayOnWakeupConfirmation()

        guard shouldPresentChoice else {
            didPromptForCutoffChoice = false
            return
        }

        guard !didPromptForCutoffChoice,
              !isBarcodeScannerPresented,
              !showSampleDayChoiceAlert,
              !showPreviousDayUnfinishedWakeupAlert,
              !showWakeupRequiredBeforeSampleAlert,
              !showDueSampleAlert,
              !showScheduleCompletionAlert else {
            return
        }

        studyDayChoiceContext = .openingAfterCutoff
        didPromptForCutoffChoice = true
        selectedTab = 1
        showSampleDayChoiceAlert = true
    }

    private func isWakeupSampleConfiguredForTodayChoice() -> Bool {
        alarmVM.timeIntervals.first == 0
    }

    private func continueWithPreviousStudyDate() {
        if studyDayChoiceContext == .openingAfterCutoff {
            didPromptForCutoffChoice = false
            currentAlarmId = nil
            scannerSource = nil
            pendingWakeupConfirmationTime = nil
            selectedTab = 1
            return
        }

        guard let previousDaySampleId = alarmVM.lastMissingSampleIdForCurrentStudyDay() else {
            isBarcodeScannerPresented = false
            currentAlarmId = nil
            scannerSource = nil
            pendingWakeupConfirmationTime = nil
            return
        }

        currentAlarmId = previousDaySampleId
        scannerSource = .schedule
        selectedTab = previousDaySampleId == AlarmConstants.eveningAlarmId ? 2 : 1
        shouldFinishPreviousDayAfterLateScan = true
        skipDayChoiceForNextScannerPresentation = true
        isBarcodeScannerPresented = true
    }

    private func continueWithCurrentStudyDate() {
        let wakeupTime = Date()
        if studyDayChoiceContext == .openingAfterCutoff,
           alarmVM.finishPendingPreviousStudyDayAndKeepWakeupPending() {
            didPromptForCutoffChoice = false
            isBarcodeScannerPresented = false
            currentAlarmId = nil
            scannerSource = nil
            pendingWakeupConfirmationTime = nil
            selectedTab = 1
            return
        }

        alarmVM.finishPreviousStudyDayAndStartTodayForScan(at: wakeupTime)
        didPromptForCutoffChoice = false

        if alarmVM.isStudyFinished() {
            isBarcodeScannerPresented = false
            selectedTab = 2
            scheduleCompletionTitle = localizedAppString("Study Finished")
            scheduleCompletionMessage = localizedAppString("This was your last sample. Thank you for participating in the study! Please export your logs and send them to your study contact email.")
            showScheduleCompletionAlert = true
            currentAlarmId = nil
            scannerSource = nil
            pendingWakeupConfirmationTime = nil
            return
        }

        guard let currentAlarm = alarmVM.getCurrentlyTriggeredAlarm() else {
            isBarcodeScannerPresented = false
            currentAlarmId = nil
            scannerSource = nil
            pendingWakeupConfirmationTime = nil
            selectedTab = 1
            presentPostWakeupSampleMessageIfNeeded(wakeupTime: wakeupTime)
            return
        }

        currentAlarmId = currentAlarm.id
        scannerSource = .wakeup
        skipDayChoiceForNextScannerPresentation = true
        isBarcodeScannerPresented = true
    }

    private func presentPostWakeupSampleMessageIfNeeded(wakeupTime: Date) {
        guard let nextTimedAlarm = alarmVM.getNextUpcomingAlarm() else {
            return
        }

        let delayedSampleMinutes = Int(
            ceil(nextTimedAlarm.time.timeIntervalSince(wakeupTime) / 60)
        )
        scheduleCompletionTitle = localizedAppString("Delayed sample planned")
        scheduleCompletionMessage = String(
            format: localizedAppString("A delayed sample is planned for your study. You will receive a reminder to take that sample in %lld minutes."),
            Int64(delayedSampleMinutes)
        )
        showScheduleCompletionAlert = true
    }

    @ViewBuilder
    private func tabItemLabel(title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.large)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private func announceCurrentTab() {
        let message: String
        switch selectedTab {
        case 0:
            message = localizedAppString("Wakeup tab")
        case 1:
            message = localizedAppString("Schedule tab")
        case 2:
            message = localizedAppString("Bedtime tab")
        default:
            message = localizedAppString("Current tab")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            postAccessibilityScreenChanged(nil)
            postAccessibilityAnnouncement(message)
        }
    }

    private func handleForegroundNotification(_ notification: Notification) {
        guard let identifier = notification.userInfo?["identifier"] as? String else {
            return
        }

        if isBarcodeScannerPresented {
            pendingForegroundNotificationIdentifier = identifier
            return
        }

        presentDueSampleAlert(for: identifier)
    }

    private func presentPendingDueSampleAlertIfNeeded() {
        guard !isBarcodeScannerPresented, let identifier = pendingForegroundNotificationIdentifier else {
            return
        }

        pendingForegroundNotificationIdentifier = nil
        presentDueSampleAlert(for: identifier)
    }

    private func presentDueSampleAlert(for identifier: String) {
        guard let alertContext = dueSampleAlertContext(for: identifier) else {
            return
        }

        currentAlarmId = alertContext.alarmId
        scannerSource = alertContext.scannerSource
        selectedTab = alertContext.selectedTab
        dueSampleAlertTitle = alertContext.title
        showDueSampleAlert = true
    }

    private func dueSampleAlertContext(for identifier: String) -> (alarmId: Int, scannerSource: ScannerPresentationSource, selectedTab: Int, title: String)? {
        guard let alarmId = Int(identifier.split(separator: "_").first ?? "") else {
            return nil
        }

            if alarmId == AlarmConstants.initialAlarmId {
                alarmVM.setUpcomingAlarmTriggered()
                if alarmVM.shouldFinishPreviousDayOnWakeupConfirmation() {
                    initialAlarmTime = Date()
                    selectedTab = 0
                    showPreviousDayUnfinishedWakeupAlert = true
                    return nil
                }

            guard let triggeredAlarm = alarmVM.getCurrentlyTriggeredAlarm() else {
                return nil
            }

            return (
                alarmId: triggeredAlarm.id,
                scannerSource: .wakeup,
                selectedTab: 0,
                title: String(
                    format: localizedAppString("Sample #%@ is due."),
                    sampleDisplayNumber(for: triggeredAlarm.id)
                )
            )
        }

        if alarmId == AlarmConstants.eveningAlarmId {
            return (
                alarmId: alarmId,
                scannerSource: .notification,
                selectedTab: 2,
                title: String(
                    format: localizedAppString("Sample #%@ is due."),
                    sampleDisplayNumber(for: alarmId)
                )
            )
        }

        guard let alarm = alarmVM.getAlarmById(alarmId: alarmId) else {
            return nil
        }

        if !alarm.isTriggered {
            alarmVM.modifyAlarmById(alarm: alarm.setTriggered())
        }

        let source: ScannerPresentationSource = alarmVM.getInitialAlarm().isTriggered && alarmId == alarmVM.timedAlarms.first?.id ? .wakeup : .notification
        return (
            alarmId: alarmId,
            scannerSource: source,
            selectedTab: 1,
            title: String(
                format: localizedAppString("Sample #%@ is due."),
                sampleDisplayNumber(for: alarmId)
            )
        )
    }

    private func sampleDisplayNumber(for alarmId: Int) -> String {
        if alarmId == AlarmConstants.eveningAlarmId {
            if let startIndex = Int(studyDataVM.studyData.startSample.dropFirst()) {
                return "\(studyDataVM.studyData.eveningSampleId + startIndex)"
            }
            return "\(studyDataVM.studyData.eveningSampleId)"
        }

        if let alarm = alarmVM.getAlarmById(alarmId: alarmId) {
            return "\(alarm.getSalivaId(startSample: studyDataVM.studyData.startSample))"
        }

        return "\(alarmId)"
    }
    
    func checkScannerStatus() {
        if isBarcodeScannerPresented {
            return
        }

        if let alarmKitIdentifier = consumePendingAlarmKitOpenIdentifier() {
            appDelegate.openedFromNotification = true
            appDelegate.lastNotificationIdentifier = alarmKitIdentifier
        }

        if appDelegate.openedFromNotification {
            defer {
                appDelegate.resetNotificationNavigationState()
            }

            if let tappedAlarmId = tappedAlarmId() {
                if tappedAlarmId == AlarmConstants.initialAlarmId {
                    alarmVM.setUpcomingAlarmTriggered()
                    if alarmVM.shouldFinishPreviousDayOnWakeupConfirmation() {
                        initialAlarmTime = Date()
                        selectedTab = 0
                        showPreviousDayUnfinishedWakeupAlert = true
                        return
                    }

                    if let alarm = alarmVM.getCurrentlyTriggeredAlarm() {
                        currentAlarmId = alarm.id
                        scannerSource = .wakeup
                        pendingWakeupConfirmationTime = Date()
                        isBarcodeScannerPresented = true
                    }
                } else if tappedAlarmId == AlarmConstants.eveningAlarmId {
                    currentAlarmId = tappedAlarmId
                    scannerSource = .notification
                    selectedTab = 2
                    isBarcodeScannerPresented = true
                } else if let tappedAlarm = alarmVM.getAlarmById(alarmId: tappedAlarmId) {
                    currentAlarmId = tappedAlarmId
                    if !tappedAlarm.isTriggered {
                        alarmVM.modifyAlarmById(alarm: tappedAlarm.setTriggered())
                    }
                    scannerSource = alarmVM.getInitialAlarm().isTriggered && tappedAlarmId == alarmVM.timedAlarms.first?.id ? .wakeup : .notification
                    if shouldRequireWakeupBeforeSampleScan() {
                        selectedTab = 1
                        showWakeupRequiredBeforeSampleAlert = true
                    } else {
                        preparePendingWakeupConfirmationIfNeeded()
                        isBarcodeScannerPresented = true
                    }
                }
            } else {
                // fallback when no specific notification identifier is available
                alarmVM.setUpcomingAlarmTriggered()
                if alarmVM.shouldFinishPreviousDayOnWakeupConfirmation() {
                    initialAlarmTime = Date()
                    selectedTab = 0
                    showPreviousDayUnfinishedWakeupAlert = true
                    return
                }

                if let alarm = alarmVM.getCurrentlyTriggeredAlarm() {
                    currentAlarmId = alarm.id
                    scannerSource = alarmVM.getInitialAlarm().isTriggered && alarm.id == alarmVM.timedAlarms.first?.id ? .wakeup : .notification
                    if shouldRequireWakeupBeforeSampleScan() {
                        selectedTab = 1
                        showWakeupRequiredBeforeSampleAlert = true
                    } else {
                        preparePendingWakeupConfirmationIfNeeded()
                        isBarcodeScannerPresented = true
                    }
                }
            }
        }
    }

    private func tappedAlarmId() -> Int? {
        guard let identifier = appDelegate.lastNotificationIdentifier else {
            return nil
        }

        return Int(identifier.split(separator: "_").first ?? "")
    }

    private func shouldRequireWakeupBeforeSampleScan() -> Bool {
        guard let currentAlarmId,
              scannerSource != .wakeup,
              currentAlarmId != AlarmConstants.eveningAlarmId,
              currentAlarmId != AlarmConstants.initialAlarmId else {
            return false
        }

        return !alarmVM.isWakeupConfirmedToday()
    }

    private func preparePendingWakeupConfirmationIfNeeded() {
        guard scannerSource == .wakeup, !alarmVM.isWakeupConfirmedToday() else {
            return
        }

        pendingWakeupConfirmationTime = Date()
    }

    private func consumePendingAlarmKitOpenIdentifier() -> String? {
        guard let identifier = UserDefaults.standard.string(forKey: AppConstants.pendingAlarmKitOpenIdentifierKey) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: AppConstants.pendingAlarmKitOpenIdentifierKey)
        return identifier
    }
    
    func initializeStudyData() {
        alarmVM.timeIntervals = studyDataVM.studyData.salivaDistances
        alarmVM.fixedTimes = studyDataVM.studyData.salivaTimes
        alarmVM.numStudyDays = studyDataVM.studyData.studyDays
        alarmVM.hasEveningSample = studyDataVM.studyData.hasEveningSample
        if let startIndex = Int(studyDataVM.studyData.startSample.dropFirst())
        {
            alarmVM.startSample = startIndex
        }
        initialAlarmTime = alarmVM.getInitialAlarm().time
        Logger.instance.setStudyData(studyName: studyDataVM.studyData.studyName, participantId: studyDataVM.studyData.participantId)
    }
    
    func updateTimedAlarms() {
        alarmVM.updateTimedAlarms()
    }
    
    func updateAlarmStatus() {
        if !Calendar.current.isDateInToday(alarmVM.dateOfLastInitialAlarm) {
            // reset to the phone's current appearance because a new day has started
            alarmVM.isDarkModeOn = nil
        }
        alarmVM.updateAlarmStatus()
    }
}

#Preview {
    let alarmVM = AlarmViewModel()
    alarmVM.initialAlarm = Alarm(id: AlarmConstants.initialAlarmId, isActive: true, isScanned: false, isTriggered: true)
    alarmVM.timedAlarms = [
        Alarm(id: 0, isActive: false, isScanned: true, isTriggered: false),
        Alarm(id: 1, isActive: true, isScanned: false, isTriggered: true),
        Alarm(id: 2, isActive: true, isScanned: false, isTriggered: false),
        Alarm(id: 3, isActive: true, isScanned: false, isTriggered: false),
        Alarm(id: 4, isActive: true, isScanned: false, isTriggered: false),
        Alarm(id: 5, isActive: true, isScanned: false, isTriggered: false)
    ]

    let permissionDataVM = PermissionDataViewModel()
    permissionDataVM.permissionData = permissionDataVM.permissionData.setCameraPermission(isGranted: true)
    permissionDataVM.permissionData = permissionDataVM.permissionData.setNotificationPermission(isGranted: true)

    let sessionVM = SessionViewModel()
    sessionVM.startStudy()

    let studyDataVM = StudyDataViewModel()
    studyDataVM.studyData = StudyData(
        isValid: true,
        studyName: "Preview Study",
        salivaDistances: [],
        salivaTimes: [
            Time(hour: 8, minute: 0),
            Time(hour: 8, minute: 15),
            Time(hour: 8, minute: 30),
            Time(hour: 8, minute: 45),
            Time(hour: 12, minute: 0),
            Time(hour: 15, minute: 0)
        ],
        startSample: "S0",
        studyDays: 1,
        numParticipants: 1,
        hasEveningSample: false,
        shareEmailAdress: "preview@example.com",
        isCheckDuplicatesEnabled: false,
        participantId: "preview"
    )

    return OngoingStudyView(alarmViewModel: alarmVM)
        .environmentObject(permissionDataVM)
        .environmentObject(sessionVM)
        .environmentObject(studyDataVM)
        .environmentObject(AppDelegate())
        .environment(\.locale, Locale(identifier: "en_US"))
}
