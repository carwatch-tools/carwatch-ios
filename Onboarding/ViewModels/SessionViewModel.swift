import Foundation

class SessionViewModel : ObservableObject {
    
    enum CurrentState {
        case registration, tutorial, studyOngoing
    }
    
    @Published private var currentState: CurrentState = .registration
    @Published var isReregistration = false
    
    func getCurrentState() -> CurrentState {
        return currentState
    }
    
    func reregister() {
        currentState = .registration
        isReregistration = true
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
