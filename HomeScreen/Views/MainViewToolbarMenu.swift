import SwiftUI
import AlertToast
import UIKit
import MessageUI

struct MainViewToolbarMenu: View {
    @EnvironmentObject var svm: SessionViewModel
    
    @Binding var showAppInfoDialog : Bool
    @Binding var appVersion: String?
    @Binding var showToast: Bool
    @Binding var killButtonClickCount: Int
    @Binding var toastType: MenuConstants.ToastType
    
    @State var showShareSheet = false
    @State var zipFileURL: URL? = nil
    
    
    var body: some View {
        Menu {
            Section("User Actions") {
                Button {
                    print("clicked share logs")
                    if let zipFileURL = Logger.instance.zipCurrentLogDirectoryContent() {
                        // ensure that state is updated already before sheet is rendered
                        DispatchQueue.main.async {
                            self.zipFileURL = zipFileURL
                            self.showShareSheet = true
                        }
                    }
                    else {
                        toastType = .zipLogsFailed
                        showToast = true
                    }
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
        .sheet(isPresented: $showShareSheet, onDismiss: {
            print("Dismiss")
        }, content: {
            if let zipFileURL = Logger.instance.zipCurrentLogDirectoryContent() {
                if MFMailComposeViewController.canSendMail() {
                    // only works if user is signed in to at least one mail account in apple mail app
                    MailViewController(recipients: ["test@kfdsj.com"],
                                       subject: "Subject",
                                       attachmentURL: zipFileURL,
                                       attachmentMimeType: "application/zip",
                                       attachmentFileName: "logFileAttachmenName.zip")
                } else {
                    // fallback if user uses a third party mail app
                    ActivityViewController(activityItems: [zipFileURL], subject: "This is the email subject")
                }
            } else {
                // TODO: debugging dummy
                MissingPermissionView(type: .camera)
            }
        })
        
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    var subject: String
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        print("ui view controller")
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        
        // Set the subject for email (optional, only works for mail-based apps)
        controller.setValue(subject, forKey: "subject")
        
        // TODO: check what to exclude here
        // Exclude some activity types if desired (e.g., exclude printing or saving to files)
        // controller.excludedActivityTypes = [.addToReadingList, .assignToContact]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

struct MailViewController: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentation
    var recipients: [String]
    var subject: String
    var messageBody: String = ""
    var attachmentURL: URL?
    var attachmentMimeType: String = ""
    var attachmentFileName: String = ""
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentation: PresentationMode
        
        init(presentation: Binding<PresentationMode>) {
            _presentation = presentation
        }
        
        // Dismiss the mail compose view controller when done
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            $presentation.wrappedValue.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(messageBody, isHTML: false)
        
        // Add attachment if provided
        if let url = attachmentURL, let data = try? Data(contentsOf: url) {
            vc.addAttachmentData(data, mimeType: attachmentMimeType, fileName: attachmentFileName)
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
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
