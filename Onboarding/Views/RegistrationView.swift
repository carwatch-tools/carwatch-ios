import SwiftUI

struct RegistrationView: View {
    
    private enum RegistrationPath {
        case participant
        case studyConfiguration
    }
    
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    
    @AppStorage(LocalizationConstants.languageStorageKey) private var selectedLanguageCode = LocalizationConstants.defaultLanguageCode
    @Binding var isScannerPresented: Bool
    @State private var permissionButtonTapped: Bool = false
    @State private var pageIndex: Int = 0
    @State private var selectedPath: RegistrationPath?
    @State private var isInfoAlertPresented: Bool = false
    @State private var isStudyConfigurationPresented: Bool = false

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
    
    private var pathSelectionTitle: LocalizedStringKey {
        switch selectedPath {
        case .participant:
            return "Participant"
        case .studyConfiguration:
            return "Study configuration"
        case nil:
            return "Continue"
        }
    }
    
    var body: some View {
        Group {
            if isStudyConfigurationPresented {
                studyConfigurationView
            } else {
                TabView(selection: $pageIndex) {
                    welcomeView
                        .tag(0)
                    
                    pathSelectionView
                        .tag(1)
                    
                    if !sessionVM.isReregistration {
                        permissionView
                            .tag(2)
                    }
                    
                    qrConfigurationView
                        .tag(3)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
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
            isInfoAlertPresented = true
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func selectionButton(title: LocalizedStringKey, systemImage: String, path: RegistrationPath) -> some View {
        Button {
            selectedPath = path
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(selectedPath == path ? .blue : .gray)
    }

    private var welcomeView: some View {
        ZStack {
            VStack {
                Spacer()
                    .frame(height: 110)
                Image("CarwatchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .padding()
                Text("Welcome to CARWatch!")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Button("Continue") {
                    pageIndex = 1
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            VStack {
                HStack {
                    infoButton()
                    Spacer()
                    languageToggleButton()
                }
                .padding(.top, 0)
                Spacer()
            }
        }
        .padding(StyleConstants.edgePadding)
        .alert("App Info", isPresented: $isInfoAlertPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This app optimizes the intake of saliva samples to monitor the Cortisol Awakening Response (CAR).\nIt consists of an alarm plus repeating timers to remind subjects to accurately take their saliva samples. To turn off the alarm, the barcode on the saliva sample needs to be scanned in order to increase compliance and reduce possible human error.\n\nDeveloper Information\nPortabiles GmbH\ncontact@portabiles.de\nHenkestr. 91\n91052 Erlangen\nGermany")
        }
    }

    private var pathSelectionView: some View {
        VStack(spacing: 20) {
            Text("How do you want to use CARWatch?")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Choose whether you want to participate in a study or prepare a study configuration.")
                .font(.system(size: StyleConstants.explanationFontSize))
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                selectionButton(
                    title: "Study participant",
                    systemImage: "person.fill",
                    path: .participant
                )
                selectionButton(
                    title: "Design a study",
                    systemImage: "slider.horizontal.3",
                    path: .studyConfiguration
                )
            }
            Button(pathSelectionTitle) {
                switch selectedPath {
                case .participant:
                    pageIndex = sessionVM.isReregistration ? 3 : 2
                case .studyConfiguration:
                    isStudyConfigurationPresented = true
                case nil:
                    break
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPath == nil)
            .padding(.top, 8)
        }
        .padding(StyleConstants.edgePadding)
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
                pageIndex = 3
            }
            .buttonStyle(.bordered)
            .disabled(!hasRequiredPermissions)
            .opacity(hasRequiredPermissions ? 1 : 0.5)
            .padding(.top, 8)
        }
        .gesture(permissionButtonTapped ? nil : DragGesture())
        .padding(StyleConstants.edgePadding)
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
        }
    }

    private var studyConfigurationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "laptopcomputer.and.arrow.down")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
                .frame(width: 100, alignment: .center)
            Text("Study Configuration")
                .font(.title.weight(.bold))
            Text("Use the CARWatch web interface to prepare and manage your study setup.")
                .font(.system(size: StyleConstants.explanationFontSize))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "alarm", text: "Specifically developed for Cortisol Awakening Response (CAR) studies")
                featureRow(icon: "house", text: "Suitable for supporting diurnal biomarker collection at home")
                featureRow(icon: "cross.case", text: "Suitable for lab-based biomarker collection")
                featureRow(icon: "checkmark.circle", text: "Supports study preparation, data collection & postprocessing")
            }
            .padding()
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
            Link(destination: URL(string: "https://mad-lab-fau.github.io/carwatch-web/")!) {
                Label("Open Study Designer", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Text("This opens the CARWatch website where your study can be configured.")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Back") {
                isStudyConfigurationPresented = false
                selectedPath = nil
            }
            .buttonStyle(.bordered)
        }
        .padding(StyleConstants.edgePadding)
    }
}

#Preview {
    RegistrationView(isScannerPresented: .constant(false))
        .environmentObject(SessionViewModel())
        .environmentObject(PermissionDataViewModel())
}
