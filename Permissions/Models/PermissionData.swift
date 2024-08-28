import Foundation

struct PermissionData : Codable {
    var notificationPermissionGranted: Bool
    let notificationPermissionDialogHandled: Bool
    var cameraPermissionGranted: Bool
    let cameraPermissionDialogHandled: Bool
    
    init(notificationPermissionGranted: Bool, notificationPermissionDialogHandled: Bool,
         cameraPermissionGranted: Bool,
         cameraPermissionDialogHandled: Bool) {
        self.notificationPermissionGranted = notificationPermissionGranted
        self.notificationPermissionDialogHandled = notificationPermissionDialogHandled
        self.cameraPermissionGranted = cameraPermissionGranted
        self.cameraPermissionDialogHandled = cameraPermissionDialogHandled
    }
    
    func setNotificationPermission(isGranted: Bool) -> PermissionData {
        return PermissionData(notificationPermissionGranted: isGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled: cameraPermissionDialogHandled)
    }
    
    func setNotificationPermissionDialogHandled() -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: true, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled: cameraPermissionDialogHandled)
    }
    
    func setCameraPermission(isGranted: Bool) -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, cameraPermissionGranted: isGranted, cameraPermissionDialogHandled:  cameraPermissionDialogHandled)
    }
    
    func setCameraPermissionDialogHandled() -> PermissionData {
        return PermissionData(notificationPermissionGranted: notificationPermissionGranted, notificationPermissionDialogHandled: notificationPermissionDialogHandled, cameraPermissionGranted: cameraPermissionGranted, cameraPermissionDialogHandled:  true)
    }
}
