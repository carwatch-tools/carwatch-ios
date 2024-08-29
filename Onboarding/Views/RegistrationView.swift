//
//  OnboardingView.swift
//  CARWatch
//
//  Created by Admin on 27.08.24.
//

import SwiftUI

struct RegistrationView: View {
    
    @EnvironmentObject var svm: SessionViewModel
    @EnvironmentObject var pvm: PermissionDataViewModel
    
    @Binding var isScannerPresented: Bool
    @State var permissionButtonTapped: Bool = false
    
    var body: some View {
        TabView {
            VStack {
                Image("CarwatchLogo")
                    .resizable()
                    .scaledToFit()
                    .padding()
                Text("Welcome to CARWatch!")
                    .font(.title.weight(.bold))
            }
            
            if !svm.isReregistration {
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
                        pvm.checkNotificationPermission()
                        pvm.checkCameraPermission()
                        permissionButtonTapped = true
                    }
                    .padding()
                    .frame(alignment: .center)
                    .buttonStyle(.borderedProminent)
                }
                .gesture(permissionButtonTapped ? nil : DragGesture())
                .padding(StyleConstants.edgePadding)
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
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

#Preview {
    @State var isScannerPresented: Bool = false
    
    return RegistrationView(isScannerPresented: $isScannerPresented).environmentObject(SessionViewModel()).environmentObject(PermissionDataViewModel())
}
