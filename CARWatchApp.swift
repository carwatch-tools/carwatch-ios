import SwiftUI

@main
struct CARWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var userDataViewModel: UserDataViewModel = UserDataViewModel()
    @StateObject var alarmViewModel: AlarmViewModel = AlarmViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView()
            .environmentObject(userDataViewModel)
            .environmentObject(alarmViewModel)
            .onAppear(){
                NotificationManager.instance.requestAuthorization { isDone in
                    print("auth request dialog handling done")
                    userDataViewModel.setNotificationPermissionDialogHandled()
                    NotificationManager.instance.reloadAuthorizationStatus { isDone in
                        print("is done")
                        switch NotificationManager.instance.authorizationStatus {
                        case .authorized:
                            print("permissions authorized")
                            userDataViewModel.setNotificationPermission(isGranted: true)
                            break
                        default:
                            userDataViewModel.setNotificationPermission(isGranted: false)
                            print(NotificationManager.instance.authorizationStatus.rawValue)
                            break
                        }
                    }
                }
            }
        }
    }
}
