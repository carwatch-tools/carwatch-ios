import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    @Published var openedFromNotification: Bool = false
    @Published var lastNotificationIdentifier: String?
    static var orientationLock = UIInterfaceOrientationMask.portrait

    func resetNotificationNavigationState() {
        openedFromNotification = false
        lastNotificationIdentifier = nil
    }

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // force portrait orientation
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
