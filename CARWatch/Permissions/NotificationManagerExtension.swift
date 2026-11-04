import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

extension NotificationManager {
    
    func reloadAuthorizationStatus(completion: @escaping (Bool) -> ()) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                completion(true)
            }
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> ()) {
        let options: UNAuthorizationOptions = [.alert, .sound]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { _, _ in
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

#if canImport(AlarmKit)
    func requestAlarmAuthorization(completion: @escaping (_ isHandled: Bool, _ isGranted: Bool) -> ()) {
        if #available(iOS 26.0, *) {
            Task {
                let isGranted: Bool
                do {
                    let state = try await AlarmManager.shared.requestAuthorization()
                    isGranted = state == .authorized
                } catch {
                    isGranted = false
                }

                await MainActor.run {
                    completion(true, isGranted)
                }
            }
        } else {
            completion(false, false)
        }
    }
#else
    func requestAlarmAuthorization(completion: @escaping (_ isHandled: Bool, _ isGranted: Bool) -> ()) {
        completion(false, false)
    }
#endif
}
