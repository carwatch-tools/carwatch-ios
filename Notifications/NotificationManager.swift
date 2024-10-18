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
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraAlarmId] = id
        msg[LoggerConstants.loggerExtraAlarmTimestamp] = getUnixTimeMillisFromDateComponent(dateComponents)
        msg[LoggerConstants.loggerTranslatedTimestamp] = translateUnixTimestamp(timeSeconds: getUnixTimeSecondsFromDateComponent(dateComponents))
        Logger.instance.log(tag: LoggerConstants.loggerActionAlarmSet, message: msg)
    }
    
    func cancelNotificationsById(alarmId: Int) {
        var notificationIds = [String]()
        for i in 0...NotificationConstants.numberOfSubsequentNotifications-1 {
            let notificationId = "\(alarmId)_\(i)"
            notificationIds.append(notificationId)
        }
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: notificationIds)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
        
        print("canceling notifications: \(notificationIds)")
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraAlarmId] = alarmId
        Logger.instance.log(tag: LoggerConstants.loggerActionAlarmCancel, message: msg)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        Logger.instance.log(tag: LoggerConstants.loggerActionAlarmKillAll, message: [String: Any]())
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
