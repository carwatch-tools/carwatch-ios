import SwiftUI

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
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error during notification permission request: \(error)")
                } else {
                    print("Sucess granting notification permission")
                }
                completion(true)
            }
        }
    }
}
