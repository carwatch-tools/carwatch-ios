import SwiftUI

struct MainView: View {
    @EnvironmentObject var pvm: PermissionDataViewModel
    @EnvironmentObject var avm: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State private var selectedTab = 0
    var numAlarms = 4 // TODO: calculate based on config
    
    @State var isScannerPresented = false
    @State var currentAlarmId: String? = nil
    
    @State private var showAppInfoDialog = false
    @State private var appVersion: String? = nil
    var body: some View {
        if pvm.permissionData.notificationPermissionGranted && pvm.permissionData.cameraPermissionGranted {
            NavigationStack{
                TabView(selection: $selectedTab){
                    WakeupView()
                        .tabItem {
                            Label("Wakeup", systemImage: "sun.max")
                        }.tag(0)
                        .padding(StyleConstants.edgePadding)
                    AlarmView(initialAlarmActive: avm.getInitialAlarm().isActive, initialAlarmTime: avm.getInitialAlarm().time, isScannerPresented: $isScannerPresented, currentAlarmId: $currentAlarmId)
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
                        MainViewToolbarMenu(showAppInfoDialog: $showAppInfoDialog, appVersion: $appVersion)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationTapped"))) { _ in
                print("opened from notification")
                checkAlarmStatus()
            }
            .onForeground {
                checkAlarmStatus()
            }
            .sheet(isPresented: $isScannerPresented) {
                ScannerView(isPresented: $isScannerPresented, alarmId: $currentAlarmId, codeType: ScannerConstants.CodeType.ean8)
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
    
    private var tabTitle: String {
        switch selectedTab {
        case 0: return String(localized: "Wakeup")
        case 1: return String(localized: "Schedule")
        case 2: return String(localized: "Bedtime")
        default: return String(localized: "Title")
        }
    }
    
    func checkAlarmStatus() {
        print("checking alarm status")
        isScannerPresented = false
        if appDelegate.openedFromNotification {
            print("opened from notification")
            // unhandled notification is present
            avm.setUpcomingAlarmTriggered()
            currentAlarmId = nil
            isScannerPresented = true
        }
        if avm.isScanRequired() {
            // no successful scan yet
            currentAlarmId = nil
            isScannerPresented = true
        }
        print("scanner presented: \(isScannerPresented)")
    }
}

#Preview{
    let pvm = PermissionDataViewModel()
    pvm.permissionData = pvm.permissionData.setCameraPermission(isGranted: true)
    pvm.permissionData = pvm.permissionData.setNotificationPermission(isGranted: true)
    return MainView().environmentObject(AlarmViewModel()).environmentObject(pvm).environmentObject(AppDelegate())
}
