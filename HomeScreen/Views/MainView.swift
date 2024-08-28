import SwiftUI
import AlertToast

struct MainView: View {
    @EnvironmentObject var pvm: PermissionDataViewModel
    @EnvironmentObject var avm: AlarmViewModel
    @EnvironmentObject var svm: SessionViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State private var selectedTab = 0
    var numAlarms = 4 // TODO: calculate based on config
    
    @State var isBarcodeScannerPresented = false
    @State var isQrCodeScannerPresented = false
    @State var currentAlarmId: String? = nil
    @State var initialAlarmTime: Date
    
    @State private var showAppInfoDialog = false
    @State private var appVersion: String? = nil
    @State private var showToast: Bool = false
    @State private var toastType: MenuConstants.ToastType = .clickToKill
    @State private var killButtonClickCount: Int = 0
    
    var body: some View {
        
        switch svm.currentState {
        case .onboardingBeforeQR:
            if pvm.permissionData.cameraPermissionDialogHandled && !pvm.permissionData.cameraPermissionGranted {
                MissingPermissionView(type: PermissionConstants.PermissionType.camera)
            } else {
                OnboardingBeforeQrView(isScannerPresented: $isQrCodeScannerPresented)
                    .environmentObject(svm)
                    .environmentObject(pvm)
                    .interactiveDismissDisabled()
                    .sheet(isPresented: $isQrCodeScannerPresented) {
                        ScannerView(isPresented: $isQrCodeScannerPresented, alarmId: $currentAlarmId, codeType: .qr)
                            .interactiveDismissDisabled()
                    }
            }
        case .onboardingAfterQR:
            if svm.isParticipantIdRequired {
                ParticipantIdView()
            } else {
                OnboardingAfterQrView()
            }
        case .studyOngoing:
            if pvm.permissionData.notificationPermissionGranted && pvm.permissionData.cameraPermissionGranted {
                NavigationStack{
                    TabView(selection: $selectedTab){
                        WakeupView(initialAlarmTime: $initialAlarmTime, isScannerPresented: $isBarcodeScannerPresented)
                            .tabItem {
                                Label("Wakeup", systemImage: "sun.max")
                            }.tag(0)
                            .padding(StyleConstants.edgePadding)
                        AlarmView(initialAlarmTime: $initialAlarmTime, isScannerPresented: $isBarcodeScannerPresented, currentAlarmId: $currentAlarmId)
                            .tabItem {
                                Label("Schedule", systemImage: "alarm")
                            }.tag(1)
                        BedtimeView()
                            .tabItem {
                                Label("Bedtime", systemImage: "bed.double")
                            }.tag(2)
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
                .sheet(isPresented: $isBarcodeScannerPresented) {
                    ScannerView(isPresented: $isBarcodeScannerPresented, alarmId: $currentAlarmId, codeType: ScannerConstants.CodeType.ean8)
                        .interactiveDismissDisabled()
                }
                
            } else if pvm.permissionData.notificationPermissionGranted {
                if pvm.permissionData.cameraPermissionDialogHandled {
                    MissingPermissionView(type: PermissionConstants.PermissionType.camera)
                } else {
                    EmptyView()
                }
            } else {
                if pvm.permissionData.notificationPermissionDialogHandled {
                    MissingPermissionView(type: PermissionConstants.PermissionType.notifications)
                } else {
                    EmptyView()
                }
            }
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
            avm.setUpcomingAlarmTriggered()
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
    
    func updateAlarmStatus() {
        print("updating alarm status")
        avm.updateAlarmStatus()
    }
}

#Preview {
    let pvm = PermissionDataViewModel()
    let avm = AlarmViewModel()
    let svm = SessionViewModel()
    
    pvm.permissionData = pvm.permissionData.setCameraPermission(isGranted: true)
    pvm.permissionData = pvm.permissionData.setNotificationPermission(isGranted: true)
    return MainView(initialAlarmTime: avm.getInitialAlarm().time).environmentObject(avm).environmentObject(pvm).environmentObject(svm).environmentObject(AppDelegate())
}
