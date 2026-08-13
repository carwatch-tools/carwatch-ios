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
        permissionDataVM.permissionData.cameraPermissionGranted
    }

    private var hasRequiredPermissionToProceed: Bool {
        permissionDataVM.permissionData.cameraPermissionGranted
    }

    private var shouldShowNotificationWarning: Bool {
        permissionDataVM.permissionData.notificationPermissionDialogHandled && !permissionDataVM.permissionData.notificationPermissionGranted
    }

    private var shouldShowAlarmWarning: Bool {
        permissionDataVM.permissionData.alarmPermissionDialogHandled && !permissionDataVM.permissionData.alarmPermissionGranted
    }

    private var shouldShowPermissionWarning: Bool {
        shouldShowNotificationWarning || shouldShowAlarmWarning || shouldShowCameraSettingsButton
    }

    private var permissionWarningText: LocalizedStringKey {
        if shouldShowNotificationWarning && shouldShowAlarmWarning {
            return "Reminders and alarm access are turned off. You will need to set alarms yourself and collect samples at the specified times."
        }

        if shouldShowAlarmWarning {
            return "Alarm access is turned off. CARWatch wakeup alarms may not ring. Please set your own wakeup alarm."
        }

        if shouldShowNotificationWarning {
            return "Notifications are turned off. You will need to set alarms yourself and collect samples at the specified times."
        }

        return "Some permissions are disabled. You can update them in Settings."
    }

    private var shouldShowCameraSettingsButton: Bool {
        permissionDataVM.permissionData.cameraPermissionDialogHandled && !permissionDataVM.permissionData.cameraPermissionGranted
    }

    private var canRequestAlarmPermission: Bool {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return true
        }
#endif
        return false
    }

    private var shouldRequestPermissions: Bool {
        !hasRequiredPermissionToProceed
            || !permissionDataVM.permissionData.notificationPermissionDialogHandled
            || (canRequestAlarmPermission && !permissionDataVM.permissionData.alarmPermissionDialogHandled)
    }

    private var shouldShowPermissionContinueButton: Bool {
        permissionDataVM.permissionData.cameraPermissionDialogHandled || hasRequiredPermissionToProceed
    }

    private func requestPermissionsAndProceedWhenReady() {
        permissionButtonTapped = true
        permissionDataVM.checkCameraPermission {
            permissionDataVM.checkNotificationPermission {
                permissionDataVM.checkAlarmPermission {
                    if hasRequiredPermissionToProceed {
                        pageIndex = qrConfigurationPageIndex
                    }
                }
            }
        }
    }

    private var currentLanguageDisplayCode: String {
        languageDisplayCode(for: selectedLanguageCode)
    }

    private func languageDisplayCode(for languageCode: String) -> String {
        languageCode.uppercased()
    }

    private func languageAccessibilityLabel(for languageCode: String) -> String {
        switch languageCode {
        case "de":
            return localizedAppString("Switch language to German")
        case "fr":
            return localizedAppString("Switch language to French")
        default:
            return localizedAppString("Switch language to English")
        }
    }

    private func selectLanguage(_ languageCode: String) {
        guard selectedLanguageCode != languageCode else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            selectedLanguageCode = languageCode
        }
    }

    private var consentPageIndex: Int { 1 }

    private var permissionPageIndex: Int { 2 }

    private var qrConfigurationPageIndex: Int {
        3
    }

    private func welcomeLogoMaxHeight(for size: CGSize) -> CGFloat {
        if usesSplitWelcomeLayout(for: size) {
            return min(size.height * 0.34, 320)
        }

        let baseHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 220 : 150
        return StyleConstants.isCompactScreen(for: size) ? min(baseHeight, 120) : baseHeight
    }

    private func usesSplitWelcomeLayout(for size: CGSize) -> Bool {
        StyleConstants.isExpandedPadLayout(for: size) && size.width >= 900 && size.height >= 800
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
            return localizedAppString("Study Participation Notice")
        case permissionPageIndex:
            return localizedAppString("Unlock Features")
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
            permissionView
        case qrConfigurationPageIndex:
            qrConfigurationView
        default:
            welcomeView
        }
    }

    @ViewBuilder
    private func languageToggleButton() -> some View {
        Menu {
            ForEach(LocalizationConstants.supportedLanguageCodes, id: \.self) { languageCode in
                Button {
                    selectLanguage(languageCode)
                } label: {
                    if selectedLanguageCode == languageCode {
                        Label(languageDisplayCode(for: languageCode), systemImage: "checkmark")
                    } else {
                        Text(languageDisplayCode(for: languageCode))
                    }
                }
                .accessibilityLabel(languageAccessibilityLabel(for: languageCode))
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text(currentLanguageDisplayCode)
                    .fontWeight(.semibold)
                    .frame(width: 28)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .accessibilityLabel(localizedAppString("Language"))
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

    private func welcomeTitleFont(for size: CGSize) -> Font {
        if usesSplitWelcomeLayout(for: size) {
            return StyleConstants.isCompactScreen(for: size) ? .title.weight(.bold) : .largeTitle.weight(.bold)
        }

        return StyleConstants.isCompactScreen(for: size) ? .title2.weight(.bold) : .title.weight(.bold)
    }

    private func welcomeDescriptionFontSize(for size: CGSize) -> CGFloat {
        let baseSize = StyleConstants.explanationFontSize(for: size)
        return usesSplitWelcomeLayout(for: size) ? baseSize + 1 : baseSize
    }

    @ViewBuilder
    private func featureRow(icon: String, text: LocalizedStringKey, size: CGSize) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.blue)
            Text(text)
                .font(.system(size: StyleConstants.explanationFontSize(for: size)))
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
                                            .font(welcomeTitleFont(for: size))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .accessibilityAddTraits(.isHeader)
                                            .accessibilityFocused($isCurrentHeaderFocused)

                                        Text("CARWatch is intended for study participants. It helps you follow your study schedule by sending reminders, and confirming samples by barcode scans.")
                                            .font(.system(size: welcomeDescriptionFontSize(for: size)))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                VStack(alignment: .leading, spacing: 16) {
                                    featureRow(icon: "person.badge.shield.checkmark", text: "Use this app only if you were invited to take part in a study.", size: size)
                                    featureRow(icon: "alarm", text: "You will receive reminders for scheduled saliva samples.", size: size)
                                    featureRow(icon: "qrcode.viewfinder", text: "You need a study QR code to set up the app.", size: size)
                                }
                                .padding(24)
                                .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))

                                Button("Continue") {
                                    pageIndex = consentPageIndex
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("registration.continue")
                                .accessibilityHint(localizedAppString("Opens the study participation information."))
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
                                        .font(welcomeTitleFont(for: size))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .accessibilityAddTraits(.isHeader)
                                        .accessibilityFocused($isCurrentHeaderFocused)

                                    Text("CARWatch is intended for study participants. It helps you follow your study schedule by sending reminders, and confirming samples by barcode scans.")
                                        .font(.system(size: welcomeDescriptionFontSize(for: size)))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    featureRow(icon: "person.badge.shield.checkmark", text: "Use this app only if you were invited to take part in a study.", size: size)
                                    featureRow(icon: "alarm", text: "You will receive reminders for scheduled saliva samples.", size: size)
                                    featureRow(icon: "qrcode.viewfinder", text: "You need a study QR code to set up the app.", size: size)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))

                                Button("Continue") {
                                    pageIndex = consentPageIndex
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("registration.continue")
                                .accessibilityHint(localizedAppString("Opens the study participation information."))
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
                        Text("Study Participation Notice")
                            .font(.title.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isCurrentHeaderFocused)

                        Text("This app is only for participants who have already been enrolled by a study team. Please review how CARWatch is used before continuing.")
                            .font(.system(size: adaptiveExplanationFontSize))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        consentSection(
                            title: "Purpose",
                            body: "CARWatch is a tool used by study teams to support scheduled saliva sample collection and barcode confirmation. The app itself does not enroll participants or define the study protocol."
                        )

                        consentSection(
                            title: "What Participation Involves",
                            body: "If your study team has invited you to use CARWatch, the app will use notifications for alarms and reminders, the camera for QR and barcode scanning, and on-device storage for study progress and log files."
                        )

                        consentSection(
                            title: "Data Handling",
                            body: "The app may store your participant ID, study configuration, barcode scan events, and app/device metadata on this device. Study-specific consent, legal basis, and data sharing are determined by the institution running your study. Log files are only shared when you explicitly export them."
                        )

                        consentSection(
                            title: "Questions Or Withdrawal",
                            body: "If you have questions about study participation, consent, privacy, or want to withdraw from a study, contact the study team using the contact details provided by your study organizer."
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
                                Text("I confirm that I am authorized by my study team to use this app and have received the study information provided by that team.")
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("registration.consentToggle")
                        .accessibilityLabel(localizedAppString("Study participation confirmation"))
                        .accessibilityValue(localizedAppString(hasAcceptedResearchConsent ? "Selected" : "Not selected"))
                        .accessibilityHint(localizedAppString("Double tap to confirm that you have read the study participation information."))

                        Group {
                            if shouldUseVerticalActionLayout {
                                VStack(alignment: .trailing, spacing: 12) {
                                    Button("Continue") {
                                        pageIndex = permissionPageIndex
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!hasAcceptedResearchConsent)
                                    .opacity(hasAcceptedResearchConsent ? 1 : 0.5)
                                    .accessibilityIdentifier("registration.consentContinue")
                                    .accessibilityHint(localizedAppString("Continues to the next registration step after confirmation is accepted."))
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                HStack {
                                    Spacer()
                                    Button("Continue") {
                                        pageIndex = permissionPageIndex
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!hasAcceptedResearchConsent)
                                    .opacity(hasAcceptedResearchConsent ? 1 : 0.5)
                                    .accessibilityIdentifier("registration.consentContinue")
                                    .accessibilityHint(localizedAppString("Continues to the next registration step after confirmation is accepted."))
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
                        Text("CARWatch requires camera access to scan sample barcodes. Notifications and alarm access are optional, but recommended for sample reminders.")
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
                            if canRequestAlarmPermission {
                                HStack {
                                    Image(systemName: "alarm.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .font(.system(size: adaptiveIconSize))
                                        .foregroundStyle(.blue)
                                        .opacity(StyleConstants.mainScreenIconOpacity)
                                        .padding()
                                        .frame(width: StyleConstants.isCompactScreen(for: screenSize) ? 64 : 80, alignment: .center)
                                        .accessibilityHidden(true)
                                    Text("Alarm access to ring for due samples, including when the phone is set to silent")
                                        .font(.system(size: adaptiveExplanationFontSize))
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        if shouldRequestPermissions {
                            Button("Next") {
                                requestPermissionsAndProceedWhenReady()
                            }
                            .padding()
                            .frame(alignment: .center)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("registration.requestPermissions")
                            .accessibilityHint(localizedAppString("Requests camera access, then optional notification and alarm permissions."))
                        }
                        if shouldShowPermissionWarning {
                            Text(permissionWarningText)
                                .font(.system(size: adaptiveExplanationFontSize))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                        if shouldShowCameraSettingsButton {
                            Button("Open Settings") {
                                openAppSettings()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("registration.openSettings")
                            .accessibilityHint(localizedAppString("Opens the iPhone settings for this app."))
                        }
                        if shouldShowPermissionContinueButton {
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

    private func openAppSettings() {
        guard let settings = PermissionConstants.appSettingsUrl else {
            return
        }

        UIApplication.shared.open(settings)
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

                        Button("Open Demo Study History") {
                            loadDemoStudyHistory()
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
        UserDefaults.standard.removeObject(forKey: AppConstants.demoOngoingStudyVariantKey)
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
        UserDefaults.standard.removeObject(forKey: AppConstants.demoOngoingStudyVariantKey)

        permissionDataVM.permissionData = PermissionData(
            notificationPermissionGranted: true,
            notificationPermissionDialogHandled: true,
            alarmPermissionGranted: true,
            alarmPermissionDialogHandled: true,
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

    private func loadDemoStudyHistory() {
        UserDefaults.standard.set(true, forKey: AppConstants.demoOngoingStudyModeKey)
        UserDefaults.standard.set("history", forKey: AppConstants.demoOngoingStudyVariantKey)

        permissionDataVM.permissionData = PermissionData(
            notificationPermissionGranted: true,
            notificationPermissionDialogHandled: true,
            alarmPermissionGranted: true,
            alarmPermissionDialogHandled: true,
            cameraPermissionGranted: true,
            cameraPermissionDialogHandled: true
        )

        studyDataVM.studyData = StudyData(
            isValid: true,
            studyName: "Demo Study History",
            salivaDistances: [0, 15, 30, 45],
            salivaTimes: [Time(hour: 12, minute: 0), Time(hour: 15, minute: 0)],
            startSample: "S1",
            studyDays: 5,
            numParticipants: 1,
            hasEveningSample: true,
            shareEmailAdress: "study@example.com",
            isCheckDuplicatesEnabled: false,
            participantId: "history-demo"
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
