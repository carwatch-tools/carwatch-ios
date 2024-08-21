import SwiftUI

@main
struct CARWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var permissionViewModel: PermissionDataViewModel = PermissionDataViewModel()
    @StateObject var alarmViewModel: AlarmViewModel = AlarmViewModel()
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainView(initialAlarmTime: alarmViewModel.getInitialAlarm().time)
                .environmentObject(permissionViewModel)
                .environmentObject(alarmViewModel)
                .environmentObject(appDelegate)
                .onAppear(){
                    checkNotificationPermission()
                    checkCameraPermission()
                }
                .onBackground {
                    // print("background")
                    // TODO: let's see if there's something useful that can be done here, otherwise remove
                }
                .onForeground {
                    checkNotificationPermission()
                    checkCameraPermission()
                }
        }
    }
    
    func checkNotificationPermission() {
        // prompt is only displayed on first launch, function is executed every time
        NotificationManager.instance.requestAuthorization { isDone in
            permissionViewModel.setNotificationPermissionDialogHandled()
            // update status every time
            NotificationManager.instance.reloadAuthorizationStatus { isDone in
                switch NotificationManager.instance.authorizationStatus {
                case .authorized:
                    permissionViewModel.setNotificationPermission(isGranted: true)
                    break
                default:
                    permissionViewModel.setNotificationPermission(isGranted: false)
                    print(NotificationManager.instance.authorizationStatus.rawValue)
                    break
                }
            }
        }
    }
    
    func checkCameraPermission() {
        // reload status every time
        CameraManager.instance.reloadCameraPermission()
        permissionViewModel.setCameraPermission(isGranted: CameraManager.instance.permissionGranted)
        // permission prompt only shown at first launch
        CameraManager.instance.requestPermission { isDone in
            permissionViewModel.setCameraPermissionDialogHandled()
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

