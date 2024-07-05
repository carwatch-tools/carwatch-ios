import SwiftUI

@main
struct CARWatchApp: App {
    
    @StateObject var alarmViewModel: AlarmViewModel = AlarmViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView()
            .environmentObject(alarmViewModel)
        }
    }
}
