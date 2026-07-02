import SwiftUI
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
#endif

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct SampleAlarmMetadata: AlarmMetadata {
    let notificationIdentifier: String
    let salivaId: String
}

@available(iOS 26.0, *)
struct OpenSampleAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open CARWatch"
    static var isDiscoverable: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Parameter(title: "Reminder Identifier")
    var notificationIdentifier: String

    init() {
        notificationIdentifier = ""
    }

    init(notificationIdentifier: String) {
        self.notificationIdentifier = notificationIdentifier
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(notificationIdentifier, forKey: AppConstants.pendingAlarmKitOpenIdentifierKey)
        await MainActor.run {
            NotificationCenter.default.post(name: .alarmKitOpenActionTapped, object: nil)
        }
        return .result()
    }
}
#endif

class NotificationManager {
    static let instance = NotificationManager() // Singleton
    var authorizationStatus: UNAuthorizationStatus = .denied
    
    func scheduleCalendarBasedNotification(id: String, salivaId: String?, day: Int,  hour: Int, minute: Int) {
        let dateComponents = DateComponents(day: day, hour: hour, minute: minute)
        if let salivaId, scheduleSampleAlarm(id: id, salivaId: salivaId, dateComponents: dateComponents) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: salivaId)
        content.sound = UNNotificationSound(named:UNNotificationSoundName(rawValue: "dummy_ringtone.caf"))
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func notificationTitle(for salivaId: String?) -> String {
        guard let salivaId else {
            return localizedAppString("Wake up! Please confirm that you are awake in CARWatch.")
        }

        if salivaId == "0" {
            return localizedAppString("Please take the first saliva sample (sample #0)!")
        }

        return String(
            format: localizedAppString("Please take saliva sample #%@!"),
            salivaId
        )
    }
    
    func cancelNotificationsById(alarmId: Int) {
        var notificationIds = [String]()
        for i in 0...NotificationConstants.numberOfSubsequentNotifications-1 {
            let notificationId = "\(alarmId)_\(i)"
            notificationIds.append(notificationId)
        }

        cancelAlarmKitAlarms(withIdentifiers: notificationIds)
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: notificationIds)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
        
        print("Canceling notifications: \(notificationIds)")
        var msg = [String: Any]()
        msg[LoggerConstants.loggerExtraAlarmId] = alarmId
        Logger.instance.log(tag: LoggerConstants.loggerActionAlarmCancel, message: msg)
    }
    
    func cancelAllNotifications() {
        cancelAllAlarmKitAlarms()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        Logger.instance.log(tag: LoggerConstants.loggerActionAlarmKillAll, message: [String: Any]())
    }

    private func scheduleSampleAlarm(id: String, salivaId: String, dateComponents: DateComponents) -> Bool {
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else {
            return false
        }

        guard shouldUseAlarmKit() else {
            return false
        }

        guard let date = nextDate(matching: dateComponents) else {
            return false
        }

        let title = notificationTitle(for: salivaId)
        let alarmId = alarmKitId(for: id)
        let metadata = SampleAlarmMetadata(notificationIdentifier: id, salivaId: salivaId)
        let stopButton = AlarmButton(
            text: LocalizedStringResource("Stop"),
            textColor: .white,
            systemImageName: "stop.fill"
        )
        let openButton = AlarmButton(
            text: LocalizedStringResource("Open CARWatch"),
            textColor: .white,
            systemImageName: "barcode.viewfinder"
        )
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: LocalizedStringResource(String.LocalizationValue(title)),
                stopButton: stopButton,
                secondaryButton: openButton,
                secondaryButtonBehavior: .custom
            )
        )
        let attributes: AlarmAttributes<SampleAlarmMetadata> = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: Color.accentColor
        )
        let configuration: AlarmManager.AlarmConfiguration<SampleAlarmMetadata> = AlarmManager.AlarmConfiguration.alarm(
            schedule: AlarmKit.Alarm.Schedule.fixed(date),
            attributes: attributes,
            secondaryIntent: OpenSampleAlarmIntent(notificationIdentifier: id),
            sound: .default
        )

        rememberAlarmKitIdentifier(id)
        Task {
            do {
                _ = try await AlarmManager.shared.schedule(id: alarmId, configuration: configuration)
            } catch {
                print("Error scheduling AlarmKit alarm \(id): \(error)")
                self.forgetAlarmKitIdentifier(id)
                self.scheduleFallbackNotification(id: id, title: title, dateComponents: dateComponents)
            }
        }
        return true
#else
        return false
#endif
    }

#if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func shouldUseAlarmKit() -> Bool {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return true
        case .denied:
            UserDefaults.standard.set(false, forKey: AppConstants.alarmKitPermissionGrantedKey)
            return false
        case .notDetermined:
            return UserDefaults.standard.bool(forKey: AppConstants.alarmKitPermissionGrantedKey)
        @unknown default:
            return false
        }
    }
#endif

    private func scheduleFallbackNotification(id: String, title: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "dummy_ringtone.caf"))
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func nextDate(matching dateComponents: DateComponents) -> Date? {
        Calendar.current.nextDate(
            after: Date().addingTimeInterval(-60),
            matching: dateComponents,
            matchingPolicy: .nextTime,
            direction: .forward
        )
    }

    private var alarmKitIdentifierStorageKey: String {
        "alarmKitNotificationIdentifiers"
    }

    private func rememberAlarmKitIdentifier(_ identifier: String) {
        var identifiers = Set(UserDefaults.standard.stringArray(forKey: alarmKitIdentifierStorageKey) ?? [])
        identifiers.insert(identifier)
        UserDefaults.standard.set(Array(identifiers), forKey: alarmKitIdentifierStorageKey)
    }

    private func forgetAlarmKitIdentifier(_ identifier: String) {
        var identifiers = Set(UserDefaults.standard.stringArray(forKey: alarmKitIdentifierStorageKey) ?? [])
        identifiers.remove(identifier)
        UserDefaults.standard.set(Array(identifiers), forKey: alarmKitIdentifierStorageKey)
    }

    private func cancelAlarmKitAlarms(withIdentifiers identifiers: [String]) {
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else {
            return
        }

        for identifier in identifiers {
            do {
                try AlarmManager.shared.cancel(id: alarmKitId(for: identifier))
                forgetAlarmKitIdentifier(identifier)
            } catch {
                print("Error canceling AlarmKit alarm \(identifier): \(error)")
            }
        }
#endif
    }

    private func cancelAllAlarmKitAlarms() {
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else {
            return
        }

        let identifiers = UserDefaults.standard.stringArray(forKey: alarmKitIdentifierStorageKey) ?? []
        for identifier in identifiers {
            do {
                try AlarmManager.shared.cancel(id: alarmKitId(for: identifier))
            } catch {
                print("Error canceling AlarmKit alarm \(identifier): \(error)")
            }
        }
        UserDefaults.standard.removeObject(forKey: alarmKitIdentifierStorageKey)
#endif
    }

#if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func alarmKitId(for identifier: String) -> AlarmKit.Alarm.ID {
        var bytes = Array("CARWatchAlarmKit".utf8)
        bytes = Array(bytes.prefix(16))

        for (offset, byte) in identifier.utf8.enumerated() {
            let index = offset % bytes.count
            bytes[index] = bytes[index] &+ byte &+ UInt8(truncatingIfNeeded: offset &* 31)
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
#endif
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // handle notification when app is in the foreground (as they are ignored per default)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Notification received with identifier \(notification.request.identifier)")
        NotificationCenter.default.post(
            name: .foregroundNotificationReceived,
            object: nil,
            userInfo: ["identifier": notification.request.identifier]
        )
        // display a banner and play the notification sound even if the app is in foreground
        completionHandler([.banner, .sound])
    }
    
    // handle notification when app is in the background
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        openedFromNotification = true
        lastNotificationIdentifier = response.notification.request.identifier
        // inform the app that notification was tapped
        NotificationCenter.default.post(name: .notificationTapped, object: nil)
        completionHandler()
    }
}
