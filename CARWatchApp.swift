import SwiftUI

@main
struct CARWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var permissionViewModel: PermissionDataViewModel = PermissionDataViewModel()
    @StateObject var sessionViewModel : SessionViewModel = SessionViewModel()
    @StateObject var studyDataViewModel : StudyDataViewModel = StudyDataViewModel()

    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(permissionViewModel)
                .environmentObject(sessionViewModel)
                .environmentObject(studyDataViewModel)
                .environmentObject(appDelegate)
                .onAppear(){
                   checkPermissionsDuringOngoingStudy()
                }
                .onBackground {
                    // print("background")
                    // TODO: let's see if there's something useful that can be done here, otherwise remove
                }
                .onForeground {
                    checkPermissionsDuringOngoingStudy()
                }
        }
    }
    
    func checkPermissionsDuringOngoingStudy() {
        // after completing onboarding, make sure all permissions are granted
        if sessionViewModel.getCurrentState() == .studyOngoing {
            permissionViewModel.checkNotificationPermission()
            permissionViewModel.checkCameraPermission()
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
