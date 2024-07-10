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
        if let encodedUserData = try? JSONEncoder().encode(permissionData) {
            UserDefaults.standard.set(encodedUserData, forKey: permissionDataKey)
        }
    }
}
