import Foundation

struct UserData : Codable {
    let notificationPermissionGranted: Bool
    let notificationPermissionDialogHandled: Bool
    
    init(notificationPermissionGranted: Bool, notificationPermissionDialogHandled: Bool) {
        self.notificationPermissionGranted = notificationPermissionGranted
        self.notificationPermissionDialogHandled = notificationPermissionDialogHandled
    }
    
    func setNotificationPermission(isGranted: Bool) -> UserData {
        return UserData(notificationPermissionGranted: isGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled)
    }
    
    func setNotificationPermissionDialogHandled() -> UserData {
        return UserData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: true)
    }
}
