import SwiftUI
import AlertToast

enum ScannerPresentationSource {
    case wakeup
    case schedule
    case notification
}

struct OngoingStudyView: View {
    @StateObject var alarmVM: AlarmViewModel
    
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State var isBarcodeScannerPresented = false
    @State var currentAlarmId: Int? = nil
    @State var initialAlarmTime: Date = getDateTomorrowMorning()
    
    @State private var selectedTab = 0
    @State private var scannerSource: ScannerPresentationSource? = nil
    
    @State private var showAppInfoDialog = false
    @State private var appVersion: String? = nil
    @State private var showToast: Bool = false
    @State private var toastType: MenuConstants.ToastType = .clickToKill
    @State private var killButtonClickCount: Int = 0

    private var preferredColorScheme: ColorScheme? {
        guard let isDarkModeOn = alarmVM.isDarkModeOn else {
            return nil
        }
        return isDarkModeOn ? .dark : .light
    }
    
    init() {
        // Use the shared property from firstViewModel for secondViewModel initialization
        _alarmVM = StateObject(wrappedValue: AlarmViewModel())
    }
    
    var body: some View {
        if permissionDataVM.permissionData.notificationPermissionGranted && permissionDataVM.permissionData.cameraPermissionGranted {
            NavigationStack{
                TabView(selection: $selectedTab){
                    WakeupView(
                        initialAlarmTime: $initialAlarmTime,
                        isScannerPresented: $isBarcodeScannerPresented,
                        scannerSource: $scannerSource,
                        onDelayedSampleAcknowledged: {
                            selectedTab = 1
                        }
                    )
                        .tabItem {
                            Label("Wakeup", systemImage: "sun.max")
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
                            Label("Schedule", systemImage: "alarm")
                        }.tag(1)
                        .environmentObject(alarmVM)
                    BedtimeView()
                        .tabItem {
                            Label("Bedtime", systemImage: "bed.double")
                        }.tag(2)
                        .environmentObject(alarmVM)
                }
                .navigationBarTitle(Text(tabTitle))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        MainViewToolbarMenu(showAppInfoDialog: $showAppInfoDialog, appVersion: $appVersion, showToast: $showToast, killButtonClickCount: $killButtonClickCount, toastType: $toastType)
                            .environmentObject(alarmVM)
                    }
                }
                .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
                    var toastMsg = ""
                    switch toastType {
                    case .clickToKill:
                        let clicksLeft = MenuConstants.killButtonClickCountActivate - killButtonClickCount
                        toastMsg = String(
                            format: String(localized: "Click %lld more times to kill all reminders!"),
                            Int64(clicksLeft)
                        )
                    case .killSuccess:
                        toastMsg = String(localized: "All reminders were deactivated!")
                    case .zipLogsFailed:
                        toastMsg = String(localized: "Generating the logs failed.\nPlease try again later!")
                    }
                    let color = Color(UIColor.secondarySystemBackground)
                    return AlertToast(displayMode: .banner(.slide), type: .regular, title: toastMsg, style: .style(backgroundColor: color))
                }
                
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationTapped"))) { _ in
                print("App opened from notification")
                updateAlarmStatus()
                checkScannerStatus()
            }
            .onForeground {
                updateAlarmStatus()
                checkScannerStatus()
            }
            .onAppear {
                initializeStudyData()
                updateTimedAlarms()
            }
            .onChange(of: isBarcodeScannerPresented) { isPresented in
                if isPresented {
                    return
                }

                if scannerSource == .wakeup && alarmVM.timedAlarms.first?.isScanned == true {
                    selectedTab = 1
                } else if scannerSource == .schedule && alarmVM.didCompleteLastScheduledSample {
                    selectedTab = 2
                }

                alarmVM.didCompleteLastScheduledSample = false
                scannerSource = nil
            }
            .sheet(isPresented: $isBarcodeScannerPresented) {
                ScannerView(isPresented: $isBarcodeScannerPresented, alarmId: $currentAlarmId, codeType: ScannerConstants.CodeType.ean8)
                    .interactiveDismissDisabled()
                    .environmentObject(alarmVM)
            }
            .preferredColorScheme(preferredColorScheme)
        } else if permissionDataVM.permissionData.notificationPermissionGranted {
            MissingPermissionView(type: PermissionConstants.PermissionType.camera)
        } else {
            MissingPermissionView(type: PermissionConstants.PermissionType.notifications)
        }
    }
    
    private var tabTitle: String {
        switch selectedTab {
        case 0: return String(localized: "Wakeup")
        case 1: return String(localized: "Schedule")
        case 2: return String(localized: "Bedtime")
        default: return String(localized: "Title")
        }
    }
    
    func checkScannerStatus() {
        isBarcodeScannerPresented = false
        if appDelegate.openedFromNotification {
            print("App opened from notification")
            if let tappedAlarmId = tappedAlarmId() {
                if tappedAlarmId == AlarmConstants.initialAlarmId {
                    alarmVM.setUpcomingAlarmTriggered()
                    if let alarm = alarmVM.getCurrentlyTriggeredAlarm() {
                        currentAlarmId = alarm.id
                        scannerSource = .wakeup
                        isBarcodeScannerPresented = true
                    }
                } else if let tappedAlarm = alarmVM.getAlarmById(alarmId: tappedAlarmId) {
                    currentAlarmId = tappedAlarmId
                    if !tappedAlarm.isTriggered {
                        alarmVM.modifyAlarmById(alarm: tappedAlarm.setTriggered())
                    }
                    scannerSource = alarmVM.getInitialAlarm().isTriggered && tappedAlarmId == alarmVM.timedAlarms.first?.id ? .wakeup : .notification
                    isBarcodeScannerPresented = true
                }
            } else {
                // fallback when no specific notification identifier is available
                alarmVM.setUpcomingAlarmTriggered()
                if let alarm = alarmVM.getCurrentlyTriggeredAlarm() {
                    currentAlarmId = alarm.id
                    scannerSource = alarmVM.getInitialAlarm().isTriggered && alarm.id == alarmVM.timedAlarms.first?.id ? .wakeup : .notification
                    isBarcodeScannerPresented = true
                }
            }

            appDelegate.lastNotificationIdentifier = nil
        }
        /*
         TODO: should the scanner be displayed if app was closed on barcode screen?
         if alarmVM.isScanRequired() {
         // no successful scan yet
         currentAlarmId = nil
         isScannerPresented = true
         }
         */
    }

    private func tappedAlarmId() -> Int? {
        guard let identifier = appDelegate.lastNotificationIdentifier else {
            return nil
        }

        return Int(identifier.split(separator: "_").first ?? "")
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
    OngoingStudyView()
}
