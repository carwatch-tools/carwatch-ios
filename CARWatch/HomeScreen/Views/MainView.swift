import SwiftUI

struct MainView: View {
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @EnvironmentObject var appDelegate: AppDelegate

    private let ongoingStudyViewBuilder: () -> AnyView
    
    @State var isQrCodeScannerPresented = false
    @State var currentAlarmId: Int? = nil

    init(ongoingStudyViewBuilder: @escaping () -> AnyView = { AnyView(OngoingStudyView()) }) {
        self.ongoingStudyViewBuilder = ongoingStudyViewBuilder
    }
    
    var body: some View {
        
        switch sessionVM.getCurrentState() {
        case .registration:
            if permissionDataVM.permissionData.cameraPermissionDialogHandled && !permissionDataVM.permissionData.cameraPermissionGranted {
                MissingPermissionView(type: PermissionConstants.PermissionType.camera)
                    .onAppear(){
                        permissionDataVM.checkCameraPermission()
                     }
            } else {
                RegistrationView(isScannerPresented: $isQrCodeScannerPresented)
                    .environmentObject(sessionVM)
                    .environmentObject(permissionDataVM)
                    .interactiveDismissDisabled()
                    .sheet(isPresented: $isQrCodeScannerPresented) {
                        ScannerView(
                            isPresented: $isQrCodeScannerPresented,
                            alarmId: $currentAlarmId,
                            pendingWakeupConfirmationTime: .constant(nil),
                            codeType: .qr
                        )
                            .interactiveDismissDisabled()
                    }
            }
        case .studyConfirmation:
            if studyDataVM.isParticipantIdRequired() {
                ParticipantIdView()
            } else {
                StudyConfirmationView()
            }
        case .tutorial:
            if studyDataVM.isParticipantIdRequired() {
                ParticipantIdView()
            } else {
                TutorialView(isPresentedFromOngoingStudy: false)
            }
        case .studyOngoing:
            ongoingStudyView()
        }
    }

    @ViewBuilder
    private func ongoingStudyView() -> some View {
#if DEBUG
        if UserDefaults.standard.bool(forKey: AppConstants.demoOngoingStudyModeKey) {
            if UserDefaults.standard.string(forKey: AppConstants.demoOngoingStudyVariantKey) == "history" {
                OngoingStudyView(alarmViewModel: makeDemoStudyHistoryAlarmViewModel())
            } else {
                OngoingStudyView(alarmViewModel: makeDemoOngoingStudyAlarmViewModel())
            }
        } else {
            ongoingStudyViewBuilder()
        }
#else
        ongoingStudyViewBuilder()
#endif
    }
}

#if DEBUG
private func makeDemoOngoingStudyAlarmViewModel() -> AlarmViewModel {
    let alarmVM = AlarmViewModel()
    let now = Date()
    var wakeupComponents = Calendar.current.dateComponents([.year, .month, .day], from: now)
    wakeupComponents.hour = 8
    wakeupComponents.minute = 0
    let initialAlarmTime = Calendar.current.date(from: wakeupComponents) ?? now
    alarmVM.initialAlarm = Alarm(
        id: AlarmConstants.initialAlarmId,
        isActive: true,
        isScanned: false,
        isTriggered: true,
        time: initialAlarmTime
    )
    alarmVM.timedAlarms = [
        Alarm(id: 0, isActive: false, isScanned: true, isTriggered: false, time: Calendar.current.date(byAdding: .minute, value: -15, to: now) ?? now),
        Alarm(id: 1, isActive: true, isScanned: false, isTriggered: true, time: Calendar.current.date(byAdding: .minute, value: -10, to: now) ?? now),
        Alarm(id: 2, isActive: true, isScanned: false, isTriggered: false, time: Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now),
        Alarm(id: 3, isActive: true, isScanned: false, isTriggered: false, time: Calendar.current.date(byAdding: .minute, value: 20, to: now) ?? now),
        Alarm(id: 4, isActive: true, isScanned: false, isTriggered: false, time: Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now),
        Alarm(id: 5, isActive: true, isScanned: false, isTriggered: false, time: Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now)
    ]
    return alarmVM
}

private func makeDemoStudyHistoryAlarmViewModel() -> AlarmViewModel {
    let alarmVM = AlarmViewModel()
    let calendar = Calendar.current
    let wakeupToday = demoDate(dayOffset: 0, hour: 8, minute: 0)

    alarmVM.numStudyDays = 5
    alarmVM.timeIntervals = [0, 15, 30, 45]
    alarmVM.fixedTimes = [Time(hour: 12, minute: 0), Time(hour: 15, minute: 0)]
    alarmVM.hasEveningSample = true
    alarmVM.startSample = 1
    let day3Wakeup = calendar.date(byAdding: .day, value: -1, to: wakeupToday) ?? wakeupToday
    alarmVM.studyDayCounter = 4
    alarmVM.dateOfLastInitialAlarm = wakeupToday
    alarmVM.setDemoConfirmedWakeupDate(day3Wakeup)
    alarmVM.setDemoStudyDaysToFinishOnWakeup([3])
    alarmVM.initialAlarm = Alarm(
        id: AlarmConstants.initialAlarmId,
        isActive: true,
        isScanned: false,
        isTriggered: true,
        time: wakeupToday
    )
    let day3DueSampleIds: Set<Int> = [4, 5]
    alarmVM.timedAlarms = demoTimedAlarms(for: day3Wakeup).map { alarm in
        Alarm(
            id: alarm.id,
            isActive: day3DueSampleIds.contains(alarm.id),
            isScanned: !day3DueSampleIds.contains(alarm.id),
            isTriggered: true,
            time: alarm.time
        )
    }
    alarmVM.isEveningScanned = true
    alarmVM.lastEveningReminderSelection = demoEveningTime(for: day3Wakeup)

    let day1Wakeup = calendar.date(byAdding: .day, value: -3, to: wakeupToday) ?? wakeupToday
    let day2Wakeup = calendar.date(byAdding: .day, value: -2, to: wakeupToday) ?? wakeupToday

    let day1Alarms = demoTimedAlarms(for: day1Wakeup).map {
        Alarm(id: $0.id, isActive: false, isScanned: true, isTriggered: true, time: $0.time)
    }
    let day2Alarms = demoTimedAlarms(for: day2Wakeup).map { alarm in
        let missedIds: Set<Int> = [2, 4]
        return Alarm(
            id: alarm.id,
            isActive: !missedIds.contains(alarm.id),
            isScanned: !missedIds.contains(alarm.id),
            isTriggered: true,
            time: alarm.time
        )
    }
    let day3Alarms = demoTimedAlarms(for: day3Wakeup).map { alarm in
        Alarm(
            id: alarm.id,
            isActive: day3DueSampleIds.contains(alarm.id),
            isScanned: !day3DueSampleIds.contains(alarm.id),
            isTriggered: true,
            time: alarm.time
        )
    }

    alarmVM.setDemoStudyDaySummaries([
        StudyDaySummary(
            studyDay: 1,
            timedAlarms: day1Alarms,
            hasEveningSample: true,
            isEveningScanned: true,
            eveningTime: demoEveningTime(for: day1Wakeup),
            finishReason: DayFinishReason.completedAllSamples.rawValue,
            isFinished: true
        ),
        StudyDaySummary(
            studyDay: 2,
            timedAlarms: day2Alarms,
            hasEveningSample: true,
            isEveningScanned: true,
            eveningTime: demoEveningTime(for: day2Wakeup),
            finishReason: DayFinishReason.userFinishedDay.rawValue,
            isFinished: true
        ),
        StudyDaySummary(
            studyDay: 3,
            timedAlarms: day3Alarms,
            hasEveningSample: true,
            isEveningScanned: true,
            eveningTime: demoEveningTime(for: day3Wakeup),
            finishReason: nil,
            isFinished: false
        )
    ])

    return alarmVM
}

private func demoTimedAlarms(for wakeupTime: Date) -> [Alarm] {
    let intervals = [0, 15, 30, 45]
    let intervalAlarms = intervals.enumerated().map { offset, minutes in
        Alarm(
            id: offset,
            isActive: true,
            isScanned: false,
            isTriggered: false,
            time: wakeupTime.addingTimeInterval(TimeInterval(minutes * 60))
        )
    }
    let fixedTimes = [
        demoTime(onSameDayAs: wakeupTime, hour: 12, minute: 0),
        demoTime(onSameDayAs: wakeupTime, hour: 15, minute: 0)
    ]
    let fixedAlarms = fixedTimes.enumerated().map { offset, time in
        Alarm(
            id: intervals.count + offset,
            isActive: true,
            isScanned: false,
            isTriggered: false,
            time: time
        )
    }
    return (intervalAlarms + fixedAlarms).sorted { $0.time < $1.time }
}

private func demoDate(dayOffset: Int, hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    return demoTime(onSameDayAs: baseDate, hour: hour, minute: minute)
}

private func demoTime(onSameDayAs date: Date, hour: Int, minute: Int) -> Date {
    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    components.hour = hour
    components.minute = minute
    components.second = 0
    return Calendar.current.date(from: components) ?? date
}

private func demoEveningTime(for date: Date) -> Date {
    demoTime(onSameDayAs: date, hour: 21, minute: 0)
}
#endif

private struct MainViewPreviewContainer: View {
    let permissionDataVM: PermissionDataViewModel
    let sessionVM: SessionViewModel
    let sessionDataVM: StudyDataViewModel
    let alarmVM: AlarmViewModel

    init() {
        let permissionDataVM = PermissionDataViewModel()
        let sessionVM = SessionViewModel()
        sessionVM.startStudy()
        let sessionDataVM = StudyDataViewModel()
        sessionDataVM.studyData = StudyData(
            isValid: true,
            studyName: "Preview Study",
            salivaDistances: [],
            salivaTimes: [
                Time(hour: 8, minute: 0),
                Time(hour: 8, minute: 2),
                Time(hour: 8, minute: 5)
            ],
            startSample: "S0",
            studyDays: 1,
            numParticipants: 1,
            hasEveningSample: false,
            shareEmailAdress: "preview@example.com",
            isCheckDuplicatesEnabled: false,
            participantId: "preview"
        )

        let alarmVM = AlarmViewModel()
        alarmVM.initialAlarm = Alarm(
            id: AlarmConstants.initialAlarmId,
            isActive: true,
            isScanned: false,
            isTriggered: true,
            time: getDateTomorrowMorning()
        )
        alarmVM.timedAlarms = [
            Alarm(id: 0, isActive: false, isScanned: true, isTriggered: false),
            Alarm(id: 1, isActive: true, isScanned: false, isTriggered: true),
            Alarm(id: 2, isActive: true, isScanned: false, isTriggered: false),
            Alarm(id: 3, isActive: true, isScanned: false, isTriggered: false),
            Alarm(id: 4, isActive: true, isScanned: false, isTriggered: false),
            Alarm(id: 5, isActive: true, isScanned: false, isTriggered: false)
        ]

        permissionDataVM.permissionData = permissionDataVM.permissionData.setCameraPermission(isGranted: true)
        permissionDataVM.permissionData = permissionDataVM.permissionData.setNotificationPermission(isGranted: true)

        self.permissionDataVM = permissionDataVM
        self.sessionVM = sessionVM
        self.sessionDataVM = sessionDataVM
        self.alarmVM = alarmVM
    }

    var body: some View {
        MainView(
            ongoingStudyViewBuilder: {
                AnyView(OngoingStudyView(alarmViewModel: alarmVM))
            }
        )
            .environmentObject(permissionDataVM)
            .environmentObject(sessionVM)
            .environmentObject(sessionDataVM)
            .environmentObject(AppDelegate())
            .environment(\.locale, currentAppLocale())
    }
}
#Preview {
    MainViewPreviewContainer()
}
