import SwiftUI

struct MainView: View {
    @EnvironmentObject var pvm: PermissionDataViewModel
    @EnvironmentObject var avm: AlarmViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    @State private var selectedTab = 0
    @State private var alarmActive: Bool = true
    @State private var alarmTime: Date = Date()
    @State private var alarmsList: [String] = ["10:10", "10:20", "10:30", "10:40", "10:50", "11:00", "12:00", "13:00", "14:00"]
    @State private var showAppInfoDialog = false
    @State private var appVersion: String? = nil
    var body: some View {
        if pvm.permissionData.notificationPermissionGranted && pvm.permissionData.cameraPermissionGranted {
            if appDelegate.openedFromNotification {
                BarcodeScannerView()
            } else {
                NavigationStack{
                    TabView(selection: $selectedTab){
                        WakeupView()
                            .tabItem {
                                Label("Wakeup", systemImage: "sun.max")
                            }.tag(0)
                        
                        AlarmView(alarmActive: avm.alarm.isActive, alarmTime: avm.alarm.time, alarmsList: $alarmsList)
                            .tabItem {
                                Label("Alarm", systemImage: "alarm")
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
        case 1: return String(localized: "Alarm")
        case 2: return String(localized: "Bedtime")
        default: return String(localized: "Title")
        }
    }
    
}

#Preview(body: {
    MainView().environmentObject(AlarmViewModel()).environmentObject(PermissionDataViewModel())
})
