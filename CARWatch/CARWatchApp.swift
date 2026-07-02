import SwiftUI

@main
struct CARWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage(LocalizationConstants.languageStorageKey) private var selectedLanguageCode = LocalizationConstants.defaultLanguageCode
    @StateObject var permissionViewModel: PermissionDataViewModel = PermissionDataViewModel()
    @StateObject var sessionViewModel : SessionViewModel = SessionViewModel()
    @StateObject var studyDataViewModel : StudyDataViewModel = StudyDataViewModel()

    @Environment(\.scenePhase) var scenePhase

    private var appLocale: Locale {
        currentAppLocale(languageCode: selectedLanguageCode)
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(permissionViewModel)
                .environmentObject(sessionViewModel)
                .environmentObject(studyDataViewModel)
                .environmentObject(appDelegate)
                .environment(\.locale, appLocale)
                .onAppear(){
                   initializeLanguageIfNeeded()
                   prewarmWelcomeLocalizations()
                   checkPermissionsDuringOngoingStudy()
                }
                .onForeground {
                    checkPermissionsDuringOngoingStudy()
                }
        }
    }

    func initializeLanguageIfNeeded() {
        guard UserDefaults.standard.object(forKey: LocalizationConstants.languageStorageKey) == nil else {
            return
        }

        selectedLanguageCode = LocalizationConstants.defaultLanguageCode
    }
    
    func checkPermissionsDuringOngoingStudy() {
        // after completing onboarding, make sure all permissions are granted
        if sessionViewModel.getCurrentState() == .studyOngoing {
#if DEBUG
            if UserDefaults.standard.bool(forKey: AppConstants.demoOngoingStudyModeKey) {
                return
            }
#endif
            permissionViewModel.checkNotificationPermission()
            permissionViewModel.checkCameraPermission()
        }
    }
}

extension View {
    func onBackground(_ f: @escaping () -> Void) -> some View {
        /// called everytime the app moves to the background
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification),
            perform: { _ in f() }
        )
    }
    
    func onForeground(_ f: @escaping () -> Void) -> some View {
        /// called everytime the app moves to the foreground
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification),
            perform: { _ in f() }
        )
    }
}
