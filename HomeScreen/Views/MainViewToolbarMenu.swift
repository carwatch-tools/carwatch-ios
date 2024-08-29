import SwiftUI
import AlertToast

struct MainViewToolbarMenu: View {
    @EnvironmentObject var svm: SessionViewModel
    
    @Binding var showAppInfoDialog : Bool
    @Binding var appVersion: String?
    @Binding var showToast: Bool
    @Binding var killButtonClickCount: Int
    @Binding var toastType: MenuConstants.ToastType
    
    
    var body: some View {
        Menu {
            Section("User Actions") {
                Button {
                    print("clicked share logs")
                } label: {
                    Label("Share Logs", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    svm.startTutorial()
                } label: {
                    Label("Show Tutorial", systemImage: "questionmark.circle")
                }
            }
            
            Section("Expert Actions"){
                Button("Delete Logs"){ }
                Button("Kill all Notifications") {
                    killButtonClickCount += 1
                    if killButtonClickCount >= MenuConstants.killButtonClickCountAlert {
                        showToast = true
                        toastType = .clickToKill
                    }
                    if killButtonClickCount == MenuConstants.killButtonClickCountActivate {
                        toastType = .killSuccess
                        NotificationManager.instance.cancelAllNotifications()
                        killButtonClickCount = 0
                    }
                }
                Button("Reregister"){ 
                    svm.reregister()
                }
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
    @State var showToast: Bool = false
    @State var killButtonClickCount: Int = 0
    @State var toastType: MenuConstants.ToastType = .clickToKill
    
    return MainViewToolbarMenu(showAppInfoDialog: $showAppInfoDialog, appVersion: $appVersion, showToast: $showToast, killButtonClickCount: $killButtonClickCount, toastType: $toastType).environmentObject(SessionViewModel())
}
