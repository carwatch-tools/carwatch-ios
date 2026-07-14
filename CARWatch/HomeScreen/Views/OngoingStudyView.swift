import SwiftUI
import AlertToast
import UIKit

enum ScannerPresentationSource {
    case wakeup
    case schedule
    case notification
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
    @State private var pendingForegroundNotificationIdentifier: String? = nil
    @State private var hasAppeared = false
    @State private var pendingBedtimeTabAfterEveningReminder = false

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
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold)
        ]

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.titleTextAttributes = normalAttributes
            itemAppearance.selected.titleTextAttributes = selectedAttributes
            itemAppearance.normal.iconColor = UIColor.systemBlue.withAlphaComponent(0.8)
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
                        scannerSource: $scannerSource
                    )
                        .tabItem {
                            tabItemLabel(title: "Schedule", systemImage: "alarm")
                        }.tag(1)
                        .environmentObject(alarmVM)
                    BedtimeView()
                        .tabItem {
                            tabItemLabel(title: "Bedtime", systemImage: "bed.double")
                        }.tag(2)
                        .environmentObject(alarmVM)
                }
                .navigationBarTitle(tabTitle)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        MainViewToolbarMenu(showAppInfoDialog: $showAppInfoDialog, appVersion: $appVersion, showToast: $showToast, killButtonClickCount: $killButtonClickCount, toastType: $toastType, selectedTab: $selectedTab)
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
            }
            .onAppear {
                configureTabBarAppearance()
                initializeStudyData()
                updateTimedAlarms()
                checkScannerStatus()
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
                    return
                }

                let scannedNonEveningSample: Bool = {
                    guard let currentAlarmId else {
                        return false
                    }

                    guard currentAlarmId != AlarmConstants.eveningAlarmId else {
                        return false
                    }

                    guard let scannedAlarm = alarmVM.getAlarmById(alarmId: currentAlarmId) else {
                        return false
                    }

                    return scannedAlarm.isScanned
                }()

                if scannerSource != nil && alarmVM.didCompleteLastScheduledSample {
                    if alarmVM.hasEveningSample && !alarmVM.isEveningScanned {
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
                        scheduleCompletionMessage = localizedAppString("You've recorded the last sample for today.\nSee you tomorrow, and don't forget to set a wakeup alarm for tomorrow.")
                    }
                    showScheduleCompletionAlert = true
                } else if scannedNonEveningSample {
                    selectedTab = 1
                }

                alarmVM.didCompleteLastScheduledSample = false
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
                    codeType: ScannerConstants.CodeType.ean8,
                    isManualScan: scannerSource == .schedule
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
                    alarmVM.confirmWakeup(at: Date())
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
                        selectedTab = 0
                        return
                    }

                    if let alarm = alarmVM.getCurrentlyTriggeredAlarm() {
                        currentAlarmId = alarm.id
                        scannerSource = .wakeup
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
                        isBarcodeScannerPresented = true
                    }
                }
            } else {
                // fallback when no specific notification identifier is available
                alarmVM.setUpcomingAlarmTriggered()
                if alarmVM.shouldFinishPreviousDayOnWakeupConfirmation() {
                    selectedTab = 0
                    return
                }

                if let alarm = alarmVM.getCurrentlyTriggeredAlarm() {
                    currentAlarmId = alarm.id
                    scannerSource = alarmVM.getInitialAlarm().isTriggered && alarm.id == alarmVM.timedAlarms.first?.id ? .wakeup : .notification
                    if shouldRequireWakeupBeforeSampleScan() {
                        selectedTab = 1
                        showWakeupRequiredBeforeSampleAlert = true
                    } else {
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
