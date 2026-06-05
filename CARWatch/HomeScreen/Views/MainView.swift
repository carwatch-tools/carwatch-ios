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
            OngoingStudyView(alarmViewModel: makeDemoOngoingStudyAlarmViewModel())
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
