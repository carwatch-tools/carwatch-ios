import SwiftUI
import UserNotifications

class NotificationManager {
    static let instance = NotificationManager() // Singleton
    var authorizationStatus: UNAuthorizationStatus = .denied
    
    //    https://stackoverflow.com/questions/71822197/calling-an-asynchronous-method-getnotificationsettings-in-the-onappear-metho
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
                    print("Sucess granting notification")
                }
                completion(true)
            }
        }
    }
    
    func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "This is a notification example"
        content.subtitle = "This is the subtitle"
        content.sound = .defaultCriticalSound(withAudioVolume: 1)
        
        // time-based notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        // calendar-based notifications - repeats every day at the given time
        var dateComponents = DateComponents()
        dateComponents.hour = 22
        dateComponents.minute = 54
        // let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        // TODO: this will only be shown when the app is not open - do we want that? otherwise: https://sarunw.com/posts/notification-in-foreground/
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
