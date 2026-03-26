import Foundation

class PermissionDataViewModel : ObservableObject {
    
    @Published var permissionData = PermissionData(notificationPermissionGranted: false, notificationPermissionDialogHandled: false, cameraPermissionGranted: false, cameraPermissionDialogHandled: false) {
        didSet {
            savePermissionData()
        }
    }
    let permissionDataKey = "permission_data"
    
    init() {
        getPermissionData()
    }
    
    func getPermissionData() {
        guard
            let data = UserDefaults.standard.data(forKey: permissionDataKey),
            let savedData = try? JSONDecoder().decode(PermissionData.self, from: data)
        else {
            return
        }
        self.permissionData = savedData
    }
    
    func setNotificationPermission(isGranted: Bool) {
        permissionData = permissionData.setNotificationPermission(isGranted: isGranted)
    }
    
    func setNotificationPermissionDialogHandled(){
        permissionData = permissionData.setNotificationPermissionDialogHandled()
    }
    
    func setCameraPermission(isGranted: Bool) {
        permissionData = permissionData.setCameraPermission(isGranted: isGranted)
    }
    
    func setCameraPermissionDialogHandled(){
        permissionData = permissionData.setCameraPermissionDialogHandled()
    }
    
    func savePermissionData() {
        if let encodedPermissionData = try? JSONEncoder().encode(permissionData) {
            UserDefaults.standard.set(encodedPermissionData, forKey: permissionDataKey)
        }
    }
    
    func checkNotificationPermission() {
        // prompt is only displayed on first launch, function is executed every time
        NotificationManager.instance.requestAuthorization { isDone in
            self.setNotificationPermissionDialogHandled()
            // update status every time
            NotificationManager.instance.reloadAuthorizationStatus { isDone in
                switch NotificationManager.instance.authorizationStatus {
                case .authorized:
                    self.setNotificationPermission(isGranted: true)
                    break
                default:
                    self.setNotificationPermission(isGranted: false)
                    break
                }
            }
        }
    }
    
    func checkCameraPermission() {
        // reload status every time
        CameraManager.instance.reloadCameraPermission()
        self.setCameraPermission(isGranted: CameraManager.instance.permissionGranted)
        // permission prompt only shown at first launch
        CameraManager.instance.requestPermission { isDone in
            self.setCameraPermissionDialogHandled()
            CameraManager.instance.reloadCameraPermission()
            self.setCameraPermission(isGranted: CameraManager.instance.permissionGranted)
        }
    }
}
