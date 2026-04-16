import SwiftUI

struct RegistrationView: View {
    @AccessibilityFocusState private var isCurrentHeaderFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @AppStorage(LocalizationConstants.languageStorageKey) private var selectedLanguageCode = LocalizationConstants.defaultLanguageCode
    @Binding var isScannerPresented: Bool
    @State private var permissionButtonTapped: Bool = false
    @State private var pageIndex: Int = 0
    @State private var hasAcceptedResearchConsent: Bool = false
    @State private var isInfoSheetPresented: Bool = false
    @State private var isPrivacyPolicyPresented: Bool = false

    private var hasRequiredPermissions: Bool {
        permissionDataVM.permissionData.cameraPermissionGranted && permissionDataVM.permissionData.notificationPermissionGranted
    }

    private var hasRequiredPermissionToProceed: Bool {
        permissionDataVM.permissionData.cameraPermissionGranted
    }

    private var shouldShowNotificationWarning: Bool {
        permissionDataVM.permissionData.notificationPermissionDialogHandled && !permissionDataVM.permissionData.notificationPermissionGranted
    }

    private var alternateLanguageCode: String {
        selectedLanguageCode == "en" ? "de" : "en"
    }

    private var alternateLanguageLabel: String {
        selectedLanguageCode == "en" ? "DE" : "EN"
    }

    private var alternateLanguageAccessibilityLabel: String {
        selectedLanguageCode == "en" ? localizedAppString("Switch language to German") : localizedAppString("Switch language to English")
    }

    private var permissionButtonTitle: LocalizedStringKey {
        hasRequiredPermissions ? "Permissions granted" : "Next"
    }

    private var consentPageIndex: Int { 1 }

    private var permissionPageIndex: Int { 2 }

    private var qrConfigurationPageIndex: Int {
        sessionVM.isReregistration ? 2 : 3
    }

    private func welcomeLogoMaxHeight(for size: CGSize) -> CGFloat {
        if usesSplitWelcomeLayout(for: size) {
            return min(size.height * 0.34, 320)
        }

        let baseHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 220 : 150
        return StyleConstants.isCompactScreen(for: size) ? min(baseHeight, 120) : baseHeight
    }

    private func usesSplitWelcomeLayout(for size: CGSize) -> Bool {
        StyleConstants.isExpandedPadLayout(for: size) && size.width >= 900
    }

    private var screenSize: CGSize {
        UIScreen.main.bounds.size
    }

    private var adaptiveEdgePadding: CGFloat {
        StyleConstants.edgePadding(for: screenSize)
    }

    private var adaptiveExplanationFontSize: CGFloat {
        StyleConstants.explanationFontSize(for: screenSize)
    }

    private var adaptiveIconSize: CGFloat {
        StyleConstants.mainScreenIconSize(for: screenSize)
    }

    private var shouldUseVerticalActionLayout: Bool {
        StyleConstants.isAccessibilitySize(dynamicTypeSize)
    }

    private var currentPageAnnouncement: String {
        switch pageIndex {
        case 0:
            return localizedAppString("Welcome to CARWatch")
        case consentPageIndex:
            return localizedAppString("Research Consent")
        case permissionPageIndex:
            return sessionVM.isReregistration ? localizedAppString("Configure the App") : localizedAppString("Unlock Features")
        case qrConfigurationPageIndex:
            return localizedAppString("Configure the App")
        default:
            return localizedAppString("Welcome to CARWatch")
        }
    }

    private func onboardingPageContainer<Content: View>(for size: CGSize, @ViewBuilder content: () -> Content) -> some View {
        let usesExpandedLayout = StyleConstants.isExpandedPadLayout(for: size)

        return VStack(spacing: 0) {
            if usesExpandedLayout {
                Spacer(minLength: StyleConstants.onboardingVerticalSpacingInset(for: size))
            }

            content()
                .frame(maxWidth: StyleConstants.onboardingContentMaxWidth(for: size) ?? .infinity, alignment: .leading)
                .padding(StyleConstants.edgePadding(for: size))
                .frame(maxWidth: .infinity, alignment: .center)

            if usesExpandedLayout {
                Spacer(minLength: StyleConstants.onboardingVerticalSpacingInset(for: size))
            }
        }
        .frame(minHeight: size.height)
    }
    
    var body: some View {
        currentRegistrationPageView
            .sheet(isPresented: $isPrivacyPolicyPresented) {
                PrivacyPolicyView()
            }
            .onAppear {
                focusCurrentHeader()
            }
            .onChange(of: pageIndex) { _ in
                focusCurrentHeader()
            }
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
        .accessibilityLabel(alternateLanguageAccessibilityLabel)
        .accessibilityHint(localizedAppString("Changes the app language for onboarding."))
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
        .accessibilityLabel(localizedAppString("Open app information"))
        .accessibilityHint(localizedAppString("Shows study and developer information."))
    }

    @ViewBuilder
    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.blue)
            Text(text)
                .font(.system(size: adaptiveExplanationFontSize))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var welcomeView: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let usesSplitLayout = usesSplitWelcomeLayout(for: size)

            ZStack(alignment: .top) {
                ScrollView {
                    onboardingPageContainer(for: size) {
                        VStack(spacing: 14) {
                        if usesSplitLayout {
                            VStack(alignment: .leading, spacing: 28) {
                                HStack(alignment: .center, spacing: 40) {
                                    Image("CarwatchLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 300, maxHeight: welcomeLogoMaxHeight(for: size))
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Welcome to CARWatch!")
                                            .font(.largeTitle.weight(.bold))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .accessibilityAddTraits(.isHeader)
                                            .accessibilityFocused($isCurrentHeaderFocused)

                                        Text("CARWatch is intended for study participants. It helps you follow your study schedule by sending reminders, and confirming samples by barcode scans.")
                                            .font(.system(size: adaptiveExplanationFontSize + 2))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                VStack(alignment: .leading, spacing: 16) {
                                    featureRow(icon: "person.badge.shield.checkmark", text: "Use this app only if you were invited to take part in a study.")
                                    featureRow(icon: "alarm", text: "You will receive reminders for scheduled saliva samples.")
                                    featureRow(icon: "qrcode.viewfinder", text: "You need a study QR code to set up the app.")
                                }
                                .padding(24)
                                .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))

                                Button("Continue") {
                                    pageIndex = consentPageIndex
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("registration.continue")
                                .accessibilityHint(localizedAppString("Opens the research consent information."))
                            }
                        } else {
                                Image("CarwatchLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: welcomeLogoMaxHeight(for: size))
                                    .padding(.horizontal, 8)
                                    .accessibilityHidden(true)

                                VStack(spacing: 8) {
                                    Text("Welcome to CARWatch!")
                                        .font(.title.weight(.bold))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .accessibilityAddTraits(.isHeader)
                                        .accessibilityFocused($isCurrentHeaderFocused)

                                    Text("CARWatch is intended for study participants. It helps you follow your study schedule by sending reminders, and confirming samples by barcode scans.")
                                        .font(.system(size: adaptiveExplanationFontSize))
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
                                .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))

                                Button("Continue") {
                                    pageIndex = consentPageIndex
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("registration.continue")
                                .accessibilityHint(localizedAppString("Opens the research consent information."))
                            }
                        }
                    }
                }

                HStack {
                    infoButton()
                    Spacer()
                    languageToggleButton()
                }
                .padding(.horizontal, StyleConstants.edgePadding(for: size))
                .padding(.top, 16)
            }
        }
        .sheet(isPresented: $isInfoSheetPresented) {
            RegistrationInfoSheet()
        }
    }

    private var consentView: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ScrollView {
                onboardingPageContainer(for: size) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Research Consent")
                            .font(.title.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isCurrentHeaderFocused)

                        Text("Please review the following information before continuing as a study participant.")
                            .font(.system(size: adaptiveExplanationFontSize))
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
                            isPrivacyPolicyPresented = true
                        } label: {
                            Label("Read Privacy Policy", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint(localizedAppString("Opens the privacy policy in a sheet."))

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
                            .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("registration.consentToggle")
                        .accessibilityLabel(localizedAppString("Research consent agreement"))
                        .accessibilityValue(localizedAppString(hasAcceptedResearchConsent ? "Selected" : "Not selected"))
                        .accessibilityHint(localizedAppString("Double tap to confirm that you have read the consent information."))

                        Group {
                            if shouldUseVerticalActionLayout {
                                VStack(alignment: .trailing, spacing: 12) {
                                    Button("Continue") {
                                        pageIndex = sessionVM.isReregistration ? qrConfigurationPageIndex : permissionPageIndex
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!hasAcceptedResearchConsent)
                                    .opacity(hasAcceptedResearchConsent ? 1 : 0.5)
                                    .accessibilityIdentifier("registration.consentContinue")
                                    .accessibilityHint(localizedAppString("Continues to the next registration step after consent is accepted."))
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                HStack {
                                    Spacer()
                                    Button("Continue") {
                                        pageIndex = sessionVM.isReregistration ? qrConfigurationPageIndex : permissionPageIndex
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!hasAcceptedResearchConsent)
                                    .opacity(hasAcceptedResearchConsent ? 1 : 0.5)
                                    .accessibilityIdentifier("registration.consentContinue")
                                    .accessibilityHint(localizedAppString("Continues to the next registration step after consent is accepted."))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var permissionView: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ScrollView {
                onboardingPageContainer(for: size) {
                    VStack(spacing: 20) {
                        Text("Unlock Features")
                            .font(.title.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isCurrentHeaderFocused)
                        Text("CARWatch requires camera access to scan sample barcodes. Notifications are optional, but recommended for reminder alarms.")
                            .font(.system(size: adaptiveExplanationFontSize))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundStyle(.blue)
                                    .opacity(StyleConstants.mainScreenIconOpacity)
                                    .padding()
                                    .frame(width: StyleConstants.isCompactScreen(for: screenSize) ? 64 : 80, alignment: .center)
                                    .accessibilityHidden(true)
                                Text("Camera access to enable scanning sample tube barcodes")
                                    .font(.system(size: adaptiveExplanationFontSize))
                            }
                            .accessibilityElement(children: .combine)
                            HStack {
                                Image(systemName: "light.beacon.max.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .font(.system(size: adaptiveIconSize))
                                    .foregroundStyle(.blue)
                                    .opacity(StyleConstants.mainScreenIconOpacity)
                                    .padding()
                                    .frame(width: StyleConstants.isCompactScreen(for: screenSize) ? 64 : 80, alignment: .center)
                                    .accessibilityHidden(true)
                                Text("Sending notifications to inform you about upcoming samples")
                                    .font(.system(size: adaptiveExplanationFontSize))
                            }
                            .accessibilityElement(children: .combine)
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
                        .accessibilityIdentifier("registration.requestPermissions")
                        .accessibilityHint(localizedAppString("Requests camera access and optional notification permissions."))
                        if shouldShowNotificationWarning {
                            Text("Notifications are turned off. You will need to set alarms yourself and collect samples at the specified times.")
                                .font(.system(size: adaptiveExplanationFontSize))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        } else if !hasRequiredPermissionToProceed {
                            Text("Please allow camera access to continue. Notifications are optional.")
                                .font(.system(size: adaptiveExplanationFontSize))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                        Button("Continue") {
                            pageIndex = qrConfigurationPageIndex
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasRequiredPermissionToProceed)
                        .opacity(hasRequiredPermissionToProceed ? 1 : 0.5)
                        .padding(.top, 8)
                        .accessibilityIdentifier("registration.permissionsContinue")
                        .accessibilityHint(localizedAppString("Continues after camera access is granted."))
                    }
                }
            }
            .gesture(permissionButtonTapped ? nil : DragGesture())
        }
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
        .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
        .accessibilityElement(children: .combine)
    }

    private var qrConfigurationView: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ScrollView {
                onboardingPageContainer(for: size) {
                    VStack(spacing: 20) {
                        Text("Configure the App")
                            .font(.title.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isCurrentHeaderFocused)
                        Text("Please scan the QR Code that you received to configure the CARWatch App for your study.")
                            .font(.system(size: adaptiveExplanationFontSize))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .font(.system(size: adaptiveIconSize))
                            .foregroundStyle(.blue)
                            .opacity(StyleConstants.mainScreenIconOpacity)
                            .padding()
                            .frame(width: StyleConstants.isCompactScreen(for: screenSize) ? 80 : 100, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityHidden(true)
                        Button("Scan now") {
                            isScannerPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("registration.scanQr")
                        .accessibilityHint(localizedAppString("Opens the QR code scanner for study setup."))

#if DEBUG
                        Button("Load Demo Study") {
                            loadDemoStudy()
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)

                        Button("Open Demo Ongoing Study") {
                            loadDemoOngoingStudy()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
#endif
                    }
                }
            }
        }
    }

#if DEBUG
    private func loadDemoStudy() {
        UserDefaults.standard.set(false, forKey: AppConstants.demoOngoingStudyModeKey)
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

    private func loadDemoOngoingStudy() {
        UserDefaults.standard.set(true, forKey: AppConstants.demoOngoingStudyModeKey)

        permissionDataVM.permissionData = PermissionData(
            notificationPermissionGranted: true,
            notificationPermissionDialogHandled: true,
            cameraPermissionGranted: true,
            cameraPermissionDialogHandled: true
        )

        studyDataVM.studyData = StudyData(
            isValid: true,
            studyName: "Preview Study",
            salivaDistances: [],
            salivaTimes: [
                Time(hour: 8, minute: 0),
                Time(hour: 8, minute: 15),
                Time(hour: 8, minute: 30),
                Time(hour: 8, minute: 45),
                Time(hour: 12, minute: 0),
                Time(hour: 15, minute: 0)
            ],
            startSample: "S0",
            studyDays: 1,
            numParticipants: 1,
            hasEveningSample: false,
            shareEmailAdress: "preview@example.com",
            isCheckDuplicatesEnabled: false,
            participantId: "preview"
        )

        sessionVM.startStudy()
    }
#endif

    private func focusCurrentHeader() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isCurrentHeaderFocused = true
            postAccessibilityScreenChanged(nil)
            postAccessibilityAnnouncement(currentPageAnnouncement)
        }
    }

}

private struct RegistrationInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPrivacyPolicyPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("This app optimizes the intake of saliva samples to monitor the Cortisol Awakening Response (CAR). It consists of an alarm plus repeating timers to remind subjects to accurately take their saliva samples. To turn off the alarm, the barcode on the saliva sample needs to be scanned in order to increase compliance and reduce possible human error.")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Developer Information")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text("Portabiles GmbH")
                        Text("contact@portabiles.de")
                        Text("Henkestr. 91")
                        Text("91052 Erlangen")
                        Text("Germany")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        isPrivacyPolicyPresented = true
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(localizedAppString("Opens the privacy policy in a sheet."))
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
            .sheet(isPresented: $isPrivacyPolicyPresented) {
                PrivacyPolicyView()
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
