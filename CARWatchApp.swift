//
//  CARWatchApp.swift
//  CARWatch
//
//  Created by Anni on 18.06.24.
//

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
