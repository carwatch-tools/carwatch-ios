import SwiftUI
import AlertToast
import UIKit
import MessageUI

struct MainViewToolbarMenu: View {
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @EnvironmentObject var alarmVM: AlarmViewModel

    @Binding var showAppInfoDialog : Bool
    @Binding var appVersion: String?
    @Binding var showToast: Bool
    @Binding var killButtonClickCount: Int
    @Binding var toastType: MenuConstants.ToastType
    
    @State var showShareSheet = false
    
    var body: some View {
        Menu {
            Section("User Actions") {
                Button {
                    if Logger.instance.zipCurrentLogDirectoryContent() != nil {
                        showShareSheet = true
                    }
                    else {
                        toastType = .zipLogsFailed
                        showToast = true
                    }
                } label: {
                    Label("Share Logs", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    sessionVM.startTutorial()
                } label: {
                    Label("Show Tutorial", systemImage: "questionmark.circle")
                }
            }
            
            Section("Expert Actions"){
                Button("Delete Logs"){ 
                    Logger.instance.deleteAllLogFiles()
                }
                Button("Kill all Notifications") {
                    toastType = .clickToKill
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
                    alarmVM.resetAlarmDataForNewUser()
                    sessionVM.reregister()
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
        .sheet(isPresented: $showShareSheet, onDismiss: {
            print("Dismiss")
        }, content: {
            if let zipFileURL = Logger.instance.zipCurrentLogDirectoryContent() {
                let subject = zipFileURL.lastPathComponent
                if MFMailComposeViewController.canSendMail() {
                    // only works if user is signed in to at least one mail account in apple mail app
                    MailViewController(recipients: [studyDataVM.studyData.shareEmailAdress],
                                       subject: subject,
                                       attachmentURL: zipFileURL,
                                       attachmentMimeType: "application/zip",
                                       attachmentFileName: subject)
                } else {
                    // fallback if user uses a third party mail app
                    // in this case, recipient can not be set automatically
                    let subject = "Please change recipient to \(studyDataVM.studyData.shareEmailAdress)! Subject: \(subject)"
                    ActivityViewController(activityItems: [zipFileURL], subject: subject)
                }
            } else {
                Text("No logs available")
            }
        })
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
