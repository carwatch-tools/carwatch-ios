import SwiftUI
import UserNotifications

class NotificationManager {
    static let instance = NotificationManager() // Singleton
    var authorizationStatus: UNAuthorizationStatus = .denied
    
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
    
    func scheduleCalendarBasedNotification(id: String, hour: Int, minute: Int) {
        // repeats every day at the given time
        let content = UNMutableNotificationContent()
        content.title = "This is a calendar-based notification"
        content.subtitle = "Time: \(hour)\(minute), ID: \(id)"
        content.sound = .defaultCriticalSound(withAudioVolume: 1)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        print("Notification scheduled: Time: \(hour)\(minute), ID: \(id)")
    }
    
    func scheduleIntervalBasedNotification(id: String, intervalSeconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "This is a calendar-based notification"
        content.subtitle = "Interval in sec: \(intervalSeconds), ID: \(id)"
        content.sound = .defaultCriticalSound(withAudioVolume: 1)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        print("Notification scheduled: Interval in sec: \(intervalSeconds), ID: \(id)")
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
