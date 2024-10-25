import Foundation

class SessionViewModel : ObservableObject {
    
    enum CurrentState: String, Codable {
        case registration, tutorial, studyOngoing
    }
    
    @Published private var currentState: CurrentState = .registration {
        didSet {
            saveCurrentState()
        }
    }
    @Published var isReregistration = false {
        didSet {
            saveRegistrationStatus()
        }
    }
    @Published var scannedBarcodes = [String]() {
        didSet {
            saveScannedBarcodes()
        }
    }
    
    let currentStateDataKey = "currentState"
    let registrationStateDataKey = "isReregistration"
    let scannedBarcodesKey = "scannedBarcodes"
    
    init() {
        getSessionData()
    }
    
    func saveCurrentState() {
        let rawStateValue = currentState.rawValue
        UserDefaults.standard.set(rawStateValue, forKey: currentStateDataKey)
    }
    
    func saveRegistrationStatus(){
        UserDefaults.standard.set(isReregistration, forKey: registrationStateDataKey)
    }

    func saveScannedBarcodes(){
        UserDefaults.standard.set(scannedBarcodes, forKey: scannedBarcodesKey)
    }
    
    func getSessionData() {
        isReregistration = UserDefaults.standard.bool(forKey: registrationStateDataKey)
        guard
            let rawStateValue = UserDefaults.standard.string(forKey: currentStateDataKey),
            let savedState = CurrentState(rawValue: rawStateValue)
        else {
            return
        }
        currentState = savedState
        scannedBarcodes = UserDefaults.standard.stringArray(forKey: scannedBarcodesKey) ?? [String]()
    }
    
    func getCurrentState() -> CurrentState {
        return currentState
    }
    
    func reregister() {
        /// reset all user and study data
        NotificationManager.instance.cancelAllNotifications()
        currentState = .registration
        isReregistration = true
        scannedBarcodes = [String]()
    }
    
    func startStudy() {
        currentState = .studyOngoing
        isReregistration = false
    }
    
    func startTutorial() {
        currentState = .tutorial
        isReregistration = false
    }
}
