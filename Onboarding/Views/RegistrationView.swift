import SwiftUI

struct RegistrationView: View {
    
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var permissionDataVM: PermissionDataViewModel
    
    @Binding var isScannerPresented: Bool
    @State private var permissionButtonTapped: Bool = false
    @State private var pageIndex: Int = 0

    private var hasRequiredPermissions: Bool {
        permissionDataVM.permissionData.cameraPermissionGranted && permissionDataVM.permissionData.notificationPermissionGranted
    }
    
    var body: some View {
        TabView(selection: $pageIndex) {
            VStack {
                Image("CarwatchLogo")
                    .resizable()
                    .scaledToFit()
                    .padding()
                Text("Welcome to CARWatch!")
                    .font(.title.weight(.bold))
                Button("Continue") {
                    pageIndex = 1
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .tag(0)
            
            if !sessionVM.isReregistration {
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
                    Button("Grant Permissions") {
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
                        pageIndex = 2
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasRequiredPermissions)
                    .opacity(hasRequiredPermissions ? 1 : 0.5)
                    .padding(.top, 8)
                }
                .gesture(permissionButtonTapped ? nil : DragGesture())
                .padding(StyleConstants.edgePadding)
                .tag(1)
            }
            
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
            .tag(sessionVM.isReregistration ? 1 : 2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

#Preview {
    RegistrationView(isScannerPresented: .constant(false))
        .environmentObject(SessionViewModel())
        .environmentObject(PermissionDataViewModel())
}
