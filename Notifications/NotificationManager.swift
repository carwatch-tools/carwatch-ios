import SwiftUI
import UserNotifications

class NotificationManager {
    static let instance = NotificationManager() // Singleton
    var authorizationStatus: UNAuthorizationStatus = .denied
    
    func scheduleCalendarBasedNotification(id: String, day: Int,  hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "This is a calendar-based notification"
        content.subtitle = "Time: \(hour)\(minute), ID: \(id)"
        content.sound = UNNotificationSound(named:UNNotificationSoundName(rawValue: "dummy_ringtone.caf"))
        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        print("Notification scheduled - Day: \(day), Time: \(hour):\(minute), ID: \(id)")
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
    
    func cancelNotificationsById(alarmId: String) {
        var notificationIds = [String]()
        for i in 0...NotificationConstants.numberOfSubsequentNotifications-1 {
            let notificationId = "\(alarmId)_\(i)"
            notificationIds.append(notificationId)
        }
        print("canceling notifications: \(notificationIds)")
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: notificationIds)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // handle notification when app is in the foreground (as they are ignored per default)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Notification received with identifier \(notification.request.identifier)")
        openedFromNotification = true
        // display a banner and play the notification sound even if the app is in foreground
        completionHandler([.banner, .sound])
    }
    
    // handle notification when app is in the background
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        openedFromNotification = true
        // inform the app that notification was tapped
        NotificationCenter.default.post(name: NSNotification.Name("NotificationTapped"), object: nil)
    }
}
