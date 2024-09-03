import SwiftUI
import AlertToast

struct OngoingStudyView: View {
    @StateObject var alarmVM: AlarmViewModel
     
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State var isBarcodeScannerPresented = false
    @State var currentAlarmId: String? = nil
    @State var initialAlarmTime: Date = getDateTomorrowMorning()

    @State private var selectedTab = 0
    
    @State private var showAppInfoDialog = false
    @State private var appVersion: String? = nil
    @State private var showToast: Bool = false
    @State private var toastType: MenuConstants.ToastType = .clickToKill
    @State private var killButtonClickCount: Int = 0
    
    init() {
        // Use the shared property from firstViewModel for secondViewModel initialization
        _alarmVM = StateObject(wrappedValue: AlarmViewModel(timeIntervals: [Int]()))
    }

    var body: some View {
        if permissionDataVM.permissionData.notificationPermissionGranted && permissionDataVM.permissionData.cameraPermissionGranted {
            NavigationStack{
                TabView(selection: $selectedTab){
                    WakeupView(initialAlarmTime: $initialAlarmTime, isScannerPresented: $isBarcodeScannerPresented)
                        .tabItem {
                            Label("Wakeup", systemImage: "sun.max")
                        }.tag(0)
                        .padding(StyleConstants.edgePadding)
                        .environmentObject(alarmVM)
                    AlarmView(initialAlarmTime: $initialAlarmTime, isScannerPresented: $isBarcodeScannerPresented, currentAlarmId: $currentAlarmId)
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
                    }
                }
                .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
                    var toastMsg = ""
                    switch toastType {
                    case .clickToKill:
                        let clicksLeft = MenuConstants.killButtonClickCountActivate - killButtonClickCount
                        toastMsg = "Click \(clicksLeft) more times to kill all reminders!"
                    case .killSuccess:
                        toastMsg = "All reminders were deactivated!"
                    }
                    let color = Color(UIColor.secondarySystemBackground)
                    return AlertToast(displayMode: .banner(.slide), type: .regular, title: toastMsg, style: .style(backgroundColor: color))
                }
                
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationTapped"))) { _ in
                print("opened from notification")
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
            .sheet(isPresented: $isBarcodeScannerPresented) {
                ScannerView(isPresented: $isBarcodeScannerPresented, alarmId: $currentAlarmId, codeType: ScannerConstants.CodeType.ean8)
                    .interactiveDismissDisabled()
                    .environmentObject(alarmVM)
            }
            
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
        print("checking alarm status")
        isBarcodeScannerPresented = false
        if appDelegate.openedFromNotification {
            print("opened from notification")
            // unhandled notification is present
            alarmVM.setUpcomingAlarmTriggered()
            currentAlarmId = nil
            isBarcodeScannerPresented = true
        }
        /*
         TODO: should the scanner be displayed if app was closed on barcode screen?
         if avm.isScanRequired() {
         // no successful scan yet
         currentAlarmId = nil
         isScannerPresented = true
         }
         */
        print("scanner presented: \(isBarcodeScannerPresented)")
    }
    
    func initializeStudyData() {
        alarmVM.timeIntervals = studyDataVM.studyData.salivaDistances
        initialAlarmTime = alarmVM.getInitialAlarm().time
    }
    
    func updateTimedAlarms() {
        alarmVM.updateTimedAlarms()
    }
    
    func updateAlarmStatus() {
        alarmVM.updateAlarmStatus()
    }
}

#Preview {
    OngoingStudyView()
}
