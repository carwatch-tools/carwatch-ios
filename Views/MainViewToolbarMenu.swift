//
//  MainViewToolbarMenu.swift
//  CARWatch
//
//  Created by Admin on 02.07.24.
//

import SwiftUI

struct MainViewToolbarMenu: View {
    @Binding var showAppInfoDialog : Bool
    @Binding var appVersion: String?
    
    var body: some View {
        Menu {
            Section("User Actions") {
                Button {
                    print("clicked share logs")
                } label: {
                    Label("Share Logs", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    print("clicked show tutorial")
                } label: {
                    Label("Show Tutorial", systemImage: "questionmark.circle")
                }
            }
            
            Section("Expert Actions"){
                Button("Delete Logs"){ }
                Button("Kill all Notifications"){ }
                Button("Reregister"){ }
            }
            
            Button("Info") {
                print("clicked app info")
                showAppInfoDialog = true
                appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                print(showAppInfoDialog)
            }
        } label: {
            Label("Menu", systemImage: "ellipsis.circle")
                .font(.title)
        }
        .alert(
            "App Info",
            isPresented: $showAppInfoDialog,
            actions: {
                Button("OK", role: .cancel){ }
            },
            message: {
                Text("App version: \(appVersion ?? String(localized:"Unknown"))")
            }
        )
    }
}

#Preview {
    @State var showAppInfoDialog: Bool = false
    @State var appVersion: String? = "preview"
    
    return MainViewToolbarMenu(showAppInfoDialog: $showAppInfoDialog, appVersion: $appVersion)
}
