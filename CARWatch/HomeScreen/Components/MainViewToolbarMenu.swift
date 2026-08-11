import SwiftUI
import AlertToast
import UIKit
import MessageUI

struct MainViewToolbarMenu: View {
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel

    @Binding var showAppInfoDialog : Bool
    @Binding var appVersion: String?
    @Binding var showToast: Bool
    @Binding var killButtonClickCount: Int
    @Binding var toastType: MenuConstants.ToastType
    @Binding var selectedTab: Int
    
    @State var showShareSheet = false
    @State private var showStudyInfoSheet = false
    @State private var showPrivacyPolicySheet = false
    @State private var showReregisterConfirmation = false
    @State private var showFinishStudyDayConfirmation = false
    @State private var showDeleteLogsConfirmation = false
    @State private var showKillNotificationsConfirmation = false
    @State private var showStudyFinishedAlert = false
    
    var body: some View {
        Menu {
            Button {
                showStudyInfoSheet = true
            } label: {
                Label("Study Information", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                sessionVM.presentInStudyTutorial(returnTab: selectedTab)
            } label: {
                Label("Tutorial", systemImage: "questionmark.circle")
            }

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

            Button(role: .destructive) {
                showKillNotificationsConfirmation = true
            } label: {
                Label("Kill Alarms", systemImage: "bell.slash")
            }

            Button {
                if alarmVM.isStudyFinished() {
                    performReregister()
                } else {
                    showReregisterConfirmation = true
                }
            } label: {
                Label("Reregister", systemImage: "qrcode.viewfinder")
            }

            Button(role: .destructive) {
                showDeleteLogsConfirmation = true
            } label: {
                Label("Delete Logs", systemImage: "trash")
            }

            Button(role: .destructive) {
                showFinishStudyDayConfirmation = true
            } label: {
                Label("Finish Study Day", systemImage: "checkmark.circle")
            }
            .disabled(!alarmVM.hasRemainingSamplesForCurrentDay() || alarmVM.studyDayCounter == 0)

            Button {
                showPrivacyPolicySheet = true
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Button {
                showAppInfoDialog = true
                appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            } label: {
                Label("App Info", systemImage: "info.circle")
            }
        } label: {
            Label("Menu", systemImage: "ellipsis.circle")
                .font(.title)
        }
        .accessibilityLabel(localizedAppString("More options"))
        .accessibilityIdentifier("main.menu")
        .accessibilityHint(localizedAppString("Opens actions such as sharing logs, viewing the tutorial, and study information."))
        .alert(
            "App Info",
            isPresented: $showAppInfoDialog,
            actions: {
                Button("OK", role: .cancel){ }
            },
            message: {
                Text("App version: \(appVersion ?? localizedAppString("Unknown"))")
            }
        )
        .alert("Study still ongoing", isPresented: $showReregisterConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reregister", role: .destructive) {
                performReregister()
            }
        } message: {
            Text("Your study is still ongoing. Are you sure you want to reregister with a new QR code?")
        }
        .alert("Finish study day?", isPresented: $showFinishStudyDayConfirmation) {
            Button("Keep Samples", role: .cancel) { }
            Button("Finish Day", role: .destructive) {
                performFinishStudyDay()
            }
        } message: {
            Text("All remaining samples for today will be canceled and the study day will be marked as finished.")
        }
        .alert("Delete logs?", isPresented: $showDeleteLogsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Logs", role: .destructive) {
                performDeleteLogs()
            }
        } message: {
            Text("All log files on this device will be permanently deleted.")
        }
        .alert("Kill alarms?", isPresented: $showKillNotificationsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Kill Alarms", role: .destructive) {
                performKillNotifications()
            }
        } message: {
            Text("All scheduled reminders will be deactivated.")
        }
        .alert(localizedAppString("Study Finished"), isPresented: $showStudyFinishedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localizedAppString("This was your last sample. Thank you for participating in the study! Please export your logs and send them to your study contact email."))
        }
        .sheet(isPresented: $showShareSheet, content: {
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
        .sheet(isPresented: $showStudyInfoSheet) {
            StudyInformationSheet(studyData: studyDataVM.studyData)
        }
        .sheet(isPresented: $showPrivacyPolicySheet) {
            PrivacyPolicyView()
        }
    }

    private func performReregister() {
#if DEBUG
        UserDefaults.standard.set(false, forKey: AppConstants.demoOngoingStudyModeKey)
#endif
        alarmVM.resetAlarmDataForNewUser()
        studyDataVM.resetStudyData()
        permissionDataVM.resetPermissionChecksForReregistration()
        sessionVM.reregister()
    }

    private func performFinishStudyDay() {
        let isFinishingCurrentStudyDate = Calendar.current.isDate(alarmVM.dateOfLastInitialAlarm, inSameDayAs: Date())
        let didFinishDay = alarmVM.finishCurrentStudyDay()

        guard didFinishDay else {
            return
        }

        selectedTab = 2
        if alarmVM.isStudyFinished() {
            showStudyFinishedAlert = true
        } else if isFinishingCurrentStudyDate {
            toastType = .studyDayFinished
            showToast = true
        }
    }

    private func performDeleteLogs() {
        Logger.instance.deleteAllLogFiles()
    }

    private func performKillNotifications() {
        NotificationManager.instance.cancelAllNotifications()
        killButtonClickCount = 0
    }
}

private struct StudyInformationSheet: View {
    let studyData: StudyData
    @Environment(\.dismiss) private var dismiss

    private var intervalDescription: String {
        if studyData.salivaDistances.isEmpty {
            return localizedAppString("No interval-based samples configured.")
        }

        return studyData.salivaDistances
            .map { "\($0) min" }
            .joined(separator: ", ")
    }

    private var fixedTimesDescription: String {
        if studyData.salivaTimes.isEmpty {
            return localizedAppString("No fixed sample times configured.")
        }

        return studyData.salivaTimes
            .map { $0.stringValue() }
            .joined(separator: ", ")
    }

    private var participantIdDescription: String {
        studyData.participantId.isEmpty ? localizedAppString("Not set") : studyData.participantId
    }

    private var contactEmailDescription: String {
        studyData.shareEmailAdress.isEmpty ? localizedAppString("Not available") : studyData.shareEmailAdress
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Study") {
                    LabeledContent("Study Name", value: studyData.studyName)
                    LabeledContent("Participant ID", value: participantIdDescription)
                    LabeledContent("Study Days", value: "\(studyData.studyDays)")
                    LabeledContent("Contact Email", value: contactEmailDescription)
                }

                Section("Sampling Plan") {
                    LabeledContent("Interval Samples", value: intervalDescription)
                    LabeledContent("Fixed Sample Times", value: fixedTimesDescription)
                    LabeledContent("Evening Sample", value: localizedAppString(studyData.hasEveningSample ? "Yes" : "No"))
                }
            }
            .navigationTitle("Study Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


#Preview {
    MainViewToolbarMenu(
        showAppInfoDialog: .constant(false),
        appVersion: .constant("preview"),
        showToast: .constant(false),
        killButtonClickCount: .constant(0),
        toastType: .constant(.clickToKill),
        selectedTab: .constant(0)
    )
    .environmentObject(SessionViewModel())
    .environmentObject(StudyDataViewModel())
    .environmentObject(AlarmViewModel())
    .environmentObject(PermissionDataViewModel())
}
