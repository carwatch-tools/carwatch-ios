import SwiftUI

@main
struct CARWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var userDataViewModel: UserDataViewModel = UserDataViewModel()
    @StateObject var alarmViewModel: AlarmViewModel = AlarmViewModel()
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(userDataViewModel)
                .environmentObject(alarmViewModel)
                .onAppear(){
                    checkNotificationPermission()
                }
                .onBackground {
                    // print("background")
                }
                .onForeground {
                    checkNotificationPermission()
                }
        }
    }
    
    func checkNotificationPermission() {
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

extension View {
    func onBackground(_ f: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification),
            perform: { _ in f() }
        )
    }
    
    func onForeground(_ f: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification),
            perform: { _ in f() }
        )
    }
}

