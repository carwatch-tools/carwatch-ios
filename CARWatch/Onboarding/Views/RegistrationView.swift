import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    @Environment(\.openURL) private var openURL
    
    @AppStorage(LocalizationConstants.languageStorageKey) private var selectedLanguageCode = LocalizationConstants.defaultLanguageCode
    @Binding var isScannerPresented: Bool
    @State private var permissionButtonTapped: Bool = false
    @State private var pageIndex: Int = 0
    @State private var hasAcceptedResearchConsent: Bool = false
    @State private var isInfoSheetPresented: Bool = false

    private var hasRequiredPermissions: Bool {
        permissionDataVM.permissionData.cameraPermissionGranted && permissionDataVM.permissionData.notificationPermissionGranted
    }

    private var alternateLanguageCode: String {
        selectedLanguageCode == "en" ? "de" : "en"
    }

    private var alternateLanguageLabel: String {
        selectedLanguageCode == "en" ? "DE" : "EN"
    }

    private var permissionButtonTitle: LocalizedStringKey {
        hasRequiredPermissions ? "Permissions granted" : "Grant Permissions"
    }

    private var consentPageIndex: Int { 1 }

    private var permissionPageIndex: Int { 2 }

    private var qrConfigurationPageIndex: Int {
        sessionVM.isReregistration ? 2 : 3
    }

    private var welcomeLogoMaxHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 220 : 150
    }
    
    var body: some View {
        currentRegistrationPageView
    }

    @ViewBuilder
    private var currentRegistrationPageView: some View {
        switch pageIndex {
        case 0:
            welcomeView
        case consentPageIndex:
            consentView
        case permissionPageIndex:
            if sessionVM.isReregistration {
                qrConfigurationView
            } else {
                permissionView
            }
        case qrConfigurationPageIndex:
            qrConfigurationView
        default:
            welcomeView
        }
    }

    @ViewBuilder
    private func languageToggleButton() -> some View {
        Button {
            selectedLanguageCode = alternateLanguageCode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(alternateLanguageLabel)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
    }

    @ViewBuilder
    private func infoButton() -> some View {
        Button {
            isInfoSheetPresented = true
        } label: {
            Image(systemName: "info.circle")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
    }

    @ViewBuilder
    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.blue)
            Text(text)
                .font(.system(size: 18))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    infoButton()
                    Spacer()
                    languageToggleButton()
                }

                Image("CarwatchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: welcomeLogoMaxHeight)
                    .padding(.horizontal, 8)

                VStack(spacing: 8) {
                    Text("Welcome to CARWatch!")
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("CARWatch is intended for study participants. It helps you follow your study schedule by sending reminders, and confirming samples by barcode scans.")
                        .font(.system(size: StyleConstants.explanationFontSize))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "person.badge.shield.checkmark", text: "Use this app only if you were invited to take part in a study.")
                    featureRow(icon: "alarm", text: "You will receive reminders for scheduled saliva samples.")
                    featureRow(icon: "qrcode.viewfinder", text: "You need a study QR code to set up the app.")
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))

                Button("Continue") {
                    pageIndex = consentPageIndex
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(.horizontal, StyleConstants.edgePadding)
        .padding(.vertical, 20)
        .sheet(isPresented: $isInfoSheetPresented) {
            RegistrationInfoSheet()
        }
    }

    private var consentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Research Consent")
                    .font(.title.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Please review the following information before continuing as a study participant.")
                    .font(.system(size: StyleConstants.explanationFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)

                consentSection(
                    title: "Purpose",
                    body: "CARWatch supports human-subject research by guiding study participants through scheduled saliva sample collection and barcode confirmation."
                )

                consentSection(
                    title: "What Participation Involves",
                    body: "If you continue, the app will use notifications for alarms and reminders, the camera for QR and barcode scanning, and on-device storage for study progress and log files."
                )

                consentSection(
                    title: "Data Handling",
                    body: "The app may store your participant ID, study configuration, barcode scan events, and app/device metadata on this device. Log files are only shared when you explicitly export them."
                )

                consentSection(
                    title: "Questions Or Withdrawal",
                    body: "If you have questions about the study, privacy, or want to withdraw, contact the study team using the contact details provided by your study organizer."
                )

                Button {
                    openURL(AppConstants.privacyPolicyURL)
                } label: {
                    Label("Read Privacy Policy", systemImage: "hand.raised")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    hasAcceptedResearchConsent.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: hasAcceptedResearchConsent ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(hasAcceptedResearchConsent ? .blue : .secondary)
                            .font(.title3)
                        Text("I have read this information and consent to continue as a study participant.")
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
                }
                .buttonStyle(.plain)

                HStack {
                    Spacer()
                    Button("Continue") {
                        pageIndex = sessionVM.isReregistration ? qrConfigurationPageIndex : permissionPageIndex
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasAcceptedResearchConsent)
                    .opacity(hasAcceptedResearchConsent ? 1 : 0.5)
                }
            }
            .padding(StyleConstants.edgePadding)
        }
    }

    private var permissionView: some View {
        VStack {
            Text("Unlock Features")
                .font(.title.weight(.bold))
                .padding(StyleConstants.edgePadding)
            Text("To enable all of the features, CARWatch requires the following permissions:")
                .font(.system(size: StyleConstants.explanationFontSize))
                .multilineTextAlignment(.leading)
            VStack(alignment:.leading) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.blue)
                        .opacity(StyleConstants.mainScreenIconOpacity)
                        .padding()
                        .frame(width: 80, alignment: .center)
                    Text("Camera access to enable scanning sample tube barcodes")
                        .font(.system(size: StyleConstants.explanationFontSize))
                    
                }
                HStack {
                    Image(systemName: "light.beacon.max.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .font(.system(size: StyleConstants.mainScreenIconSize))
                        .foregroundStyle(.blue)
                        .opacity(StyleConstants.mainScreenIconOpacity)
                        .padding()
                        .frame(width: 80, alignment: .center)
                    Text("Sending notifications to inform you about upcoming samples")
                        .font(.system(size: StyleConstants.explanationFontSize))
                }
            }
            Button(permissionButtonTitle) {
                permissionDataVM.checkNotificationPermission()
                permissionDataVM.checkCameraPermission()
                permissionButtonTapped = true
            }
            .padding()
            .frame(alignment: .center)
            .buttonStyle(.borderedProminent)
            .disabled(hasRequiredPermissions)
            .opacity(hasRequiredPermissions ? 0.5 : 1)
            if !hasRequiredPermissions {
                Text("Please grant camera and notification access to continue.")
                    .font(.system(size: StyleConstants.explanationFontSize))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            Button("Continue") {
                pageIndex = qrConfigurationPageIndex
            }
            .buttonStyle(.bordered)
            .disabled(!hasRequiredPermissions)
            .opacity(hasRequiredPermissions ? 1 : 0.5)
            .padding(.top, 8)
        }
        .gesture(permissionButtonTapped ? nil : DragGesture())
        .padding(StyleConstants.edgePadding)
    }

    @ViewBuilder
    private func consentSection(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
    }

    private var qrConfigurationView: some View {
        VStack {
            Text("Configure the App")
                .font(.title.weight(.bold))
                .padding(StyleConstants.edgePadding)
            Text("Please scan the QR Code that you received to configure the CARWatch App for your study.")
                .font(.system(size: StyleConstants.explanationFontSize))
                .multilineTextAlignment(.leading)
                .padding()
            Image(systemName: "qrcode.viewfinder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
                .padding()
                .frame(width: 100, alignment: .center)
            Button("Scan now") {
                isScannerPresented = true
            }
            .buttonStyle(.borderedProminent)

#if DEBUG
            Button("Load Demo Study") {
                loadDemoStudy()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
#endif
        }
    }

#if DEBUG
    private func loadDemoStudy() {
        studyDataVM.studyData = StudyData(
            isValid: true,
            studyName: "Demo Cortisol Awakening Response Study",
            salivaDistances: [0, 15, 30, 45],
            salivaTimes: [Time(hour: 12, minute: 0), Time(hour: 15, minute: 0)],
            startSample: "S1",
            studyDays: 3,
            numParticipants: 200,
            hasEveningSample: true,
            shareEmailAdress: "study@example.com",
            isCheckDuplicatesEnabled: true,
            participantId: "1001"
        )
        sessionVM.startStudyConfirmation()
    }
#endif

}

private struct RegistrationInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("This app optimizes the intake of saliva samples to monitor the Cortisol Awakening Response (CAR). It consists of an alarm plus repeating timers to remind subjects to accurately take their saliva samples. To turn off the alarm, the barcode on the saliva sample needs to be scanned in order to increase compliance and reduce possible human error.")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Developer Information")
                            .font(.headline)
                        Text("Portabiles GmbH")
                        Text("contact@portabiles.de")
                        Text("Henkestr. 91")
                        Text("91052 Erlangen")
                        Text("Germany")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Link(destination: AppConstants.privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(StyleConstants.edgePadding)
            }
            .navigationTitle("App Info")
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
    RegistrationView(isScannerPresented: .constant(false))
        .environmentObject(SessionViewModel())
        .environmentObject(PermissionDataViewModel())
        .environmentObject(StudyDataViewModel())
}
