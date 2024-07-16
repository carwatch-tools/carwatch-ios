import SwiftUI

struct MainView: View {
    @EnvironmentObject var pvm: PermissionDataViewModel
    @EnvironmentObject var avm: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State private var selectedTab = 0
    @State private var alarmActive: Bool = true
    @State private var alarmTime: Date = Date()
    @State private var alarmsList: [String] = ["10:10", "10:20", "10:30", "10:40", "10:50", "11:00", "12:00", "13:00", "14:00"]
    @State private var alarmsScanned: [Bool] = [true, false, false, false, false, false, false, false, false]
    
    @State private var isScannerPresented = false
    @State private var isScanSuccessful = false
    
    @State private var showAppInfoDialog = false
    @State private var appVersion: String? = nil
    var body: some View {
        ScannerView(isPresented: $isScannerPresented, isSuccessful: $isScanSuccessful, codeType: ScannerConstants.CodeType.qr)
    }
//        if pvm.permissionData.notificationPermissionGranted && pvm.permissionData.cameraPermissionGranted {
//            NavigationStack{
//                TabView(selection: $selectedTab){
//                    WakeupView()
//                        .tabItem {
//                            Label("Wakeup", systemImage: "sun.max")
//                        }.tag(0)
//                        .padding(StyleConstants.edgePadding)
//                    AlarmView(alarmActive: avm.alarm.isActive, alarmTime: avm.alarm.time, alarmsList: $alarmsList, alarmsScanned: $alarmsScanned)
//                        .tabItem {
//                            Label("Schedule", systemImage: "alarm")
//                        }.tag(1)
//                    BedtimeView()
//                        .tabItem {
//                            Label("Bedtime", systemImage: "bed.double")
//                        }.tag(2)
//                }
//                .navigationBarTitle(Text(tabTitle))
//                .toolbar {
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        MainViewToolbarMenu(showAppInfoDialog: $showAppInfoDialog, appVersion: $appVersion)
//                    }
//                }
//            }
//            .onForeground {
//                checkAlarmStatus()
//                avm.setAlarmTriggered()
//            }
//            .sheet(isPresented: $isScannerPresented) {
//                BarcodeScannerViewWithOverlay(isPresented: $isScannerPresented, isSuccessful: $isScanSuccessful)
//                    .interactiveDismissDisabled()
//            }
//        } else if pvm.permissionData.notificationPermissionGranted {
//            if pvm.permissionData.cameraPermissionDialogHandled {
//                MissingPermissionView(type: PermissionConstants.PermissionType.camera)
//            } else {
//                EmptyView()
//            }
//        } else {
//            if pvm.permissionData.notificationPermissionDialogHandled {
//                MissingPermissionView(type: PermissionConstants.PermissionType.notifications)
//            } else {
//                EmptyView()
//            }
//        }
//    }
    
    private var tabTitle: String {
        switch selectedTab {
        case 0: return String(localized: "Wakeup")
        case 1: return String(localized: "Schedule")
        case 2: return String(localized: "Bedtime")
        default: return String(localized: "Title")
        }
    }
    
    func checkAlarmStatus() {
        if appDelegate.openedFromNotification {
            // unhandled notification is present
            avm.setAlarmTriggered()
            isScannerPresented = true
        }
        if avm.isScanRequired() {
            // no successful scan yet
            isScannerPresented = true
        }
    }
}

#Preview{
    let pvm = PermissionDataViewModel()
    pvm.permissionData = pvm.permissionData.setCameraPermission(isGranted: true)
    pvm.permissionData = pvm.permissionData.setNotificationPermission(isGranted: true)
    return MainView().environmentObject(AlarmViewModel()).environmentObject(pvm).environmentObject(AppDelegate())
}
