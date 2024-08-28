import Foundation

class SessionViewModel : ObservableObject {
    
    enum CurrentState {
        case onboardingBeforeQR, onboardingAfterQR, studyOngoing
    }
    
    @Published var currentState: CurrentState = .onboardingBeforeQR
    @Published var isOnboardingRequired = true
}
