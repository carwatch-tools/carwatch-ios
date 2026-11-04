import Foundation

struct PermissionData : Codable {
    var notificationPermissionGranted: Bool
    let notificationPermissionDialogHandled: Bool
    var alarmPermissionGranted: Bool
    let alarmPermissionDialogHandled: Bool
    var cameraPermissionGranted: Bool
    let cameraPermissionDialogHandled: Bool
    
    init(notificationPermissionGranted: Bool, notificationPermissionDialogHandled: Bool,
         alarmPermissionGranted: Bool = false,
         alarmPermissionDialogHandled: Bool = false,
         cameraPermissionGranted: Bool,
         cameraPermissionDialogHandled: Bool) {
        self.notificationPermissionGranted = notificationPermissionGranted
        self.notificationPermissionDialogHandled = notificationPermissionDialogHandled
        self.alarmPermissionGranted = alarmPermissionGranted
        self.alarmPermissionDialogHandled = alarmPermissionDialogHandled
        self.cameraPermissionGranted = cameraPermissionGranted
        self.cameraPermissionDialogHandled = cameraPermissionDialogHandled
    }

    private enum CodingKeys: String, CodingKey {
        case notificationPermissionGranted
        case notificationPermissionDialogHandled
        case alarmPermissionGranted
        case alarmPermissionDialogHandled
        case cameraPermissionGranted
        case cameraPermissionDialogHandled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notificationPermissionGranted = try container.decode(Bool.self, forKey: .notificationPermissionGranted)
        notificationPermissionDialogHandled = try container.decode(Bool.self, forKey: .notificationPermissionDialogHandled)
        alarmPermissionGranted = try container.decodeIfPresent(Bool.self, forKey: .alarmPermissionGranted) ?? false
        alarmPermissionDialogHandled = try container.decodeIfPresent(Bool.self, forKey: .alarmPermissionDialogHandled) ?? false
        cameraPermissionGranted = try container.decode(Bool.self, forKey: .cameraPermissionGranted)
        cameraPermissionDialogHandled = try container.decode(Bool.self, forKey: .cameraPermissionDialogHandled)
    }
    
    func setNotificationPermission(isGranted: Bool) -> PermissionData {
        return PermissionData(notificationPermissionGranted: isGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, alarmPermissionGranted: alarmPermissionGranted, alarmPermissionDialogHandled: alarmPermissionDialogHandled, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled: cameraPermissionDialogHandled)
    }
    
    func setNotificationPermissionDialogHandled() -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: true, alarmPermissionGranted: alarmPermissionGranted, alarmPermissionDialogHandled: alarmPermissionDialogHandled, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled: cameraPermissionDialogHandled)
    }

    func setAlarmPermission(isGranted: Bool) -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, alarmPermissionGranted: isGranted, alarmPermissionDialogHandled: alarmPermissionDialogHandled, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled: cameraPermissionDialogHandled)
    }

    func setAlarmPermissionDialogHandled() -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, alarmPermissionGranted: alarmPermissionGranted, alarmPermissionDialogHandled: true, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled: cameraPermissionDialogHandled)
    }
    
    func setCameraPermission(isGranted: Bool) -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, alarmPermissionGranted: alarmPermissionGranted, alarmPermissionDialogHandled: alarmPermissionDialogHandled, cameraPermissionGranted: isGranted, cameraPermissionDialogHandled:  cameraPermissionDialogHandled)
    }
    
    func setCameraPermissionDialogHandled() -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, alarmPermissionGranted: alarmPermissionGranted, alarmPermissionDialogHandled: alarmPermissionDialogHandled, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled:  true)
    }
}
