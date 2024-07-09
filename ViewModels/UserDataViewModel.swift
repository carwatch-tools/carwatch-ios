import Foundation

class UserDataViewModel : ObservableObject {
    
    @Published var userData = UserData(notificationPermissionGranted: false, notificationPermissionDialogHandled: false) {
        didSet {
            saveUserData()
        }
    }
    let userDataKey = "user_data"
    
    init() {
        getUserData()
    }
    
    func getUserData() {
        guard
            let userData = UserDefaults.standard.data(forKey: userDataKey),
            let savedUserData = try? JSONDecoder().decode(UserData.self, from: userData)
        else {
            return
        }
        self.userData = savedUserData
    }
    
    func setNotificationPermission(isGranted: Bool) {
        userData = userData.setNotificationPermission(isGranted: isGranted)
    }
    
    func setNotificationPermissionDialogHandled(){
        userData = userData.setNotificationPermissionDialogHandled()
    }
    
    func saveUserData() {
        if let encodedUserData = try? JSONEncoder().encode(userData) {
            UserDefaults.standard.set(encodedUserData, forKey: userDataKey)
        }
    }
}
