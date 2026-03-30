import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    policySection(
                        title: "Overview",
                        body: "CARWatch helps participants follow study-specific saliva sampling schedules. The app uses alarms, notifications, and barcode scanning to support sample collection compliance."
                    )

                    policySection(
                        title: "Data Stored In The App",
                        body: "CARWatch stores study configuration data, participant ID, scanned barcode history, alarm state, and app logs on the device so the study workflow can function and progress can be documented."
                    )

                    policySection(
                        title: "Camera Access",
                        body: "Camera access is used only to scan QR codes for study configuration and barcodes on saliva sample tubes. CARWatch does not use the camera for photos or video recording."
                    )

                    policySection(
                        title: "Notifications",
                        body: "Notification access is used to deliver wake-up alarms and sample reminders that are part of the study workflow."
                    )

                    policySection(
                        title: "Log Files",
                        body: "CARWatch creates log files on the device that may include participant ID, study metadata, barcode scan events, and device/app version information. These logs remain on the device until the user shares or deletes them."
                    )

                    policySection(
                        title: "Data Sharing",
                        body: "CARWatch does not automatically transmit study data to a server. Log files are only shared when the user explicitly chooses to export them using the in-app share or mail options."
                    )

                    policySection(
                        title: "Contact",
                        body: "For questions about privacy or study participation, contact the study team or app provider listed in the app information."
                    )
                }
                .padding(StyleConstants.edgePadding)
            }
            .navigationTitle("Privacy Policy")
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

    @ViewBuilder
    private func policySection(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PrivacyPolicyView()
}
