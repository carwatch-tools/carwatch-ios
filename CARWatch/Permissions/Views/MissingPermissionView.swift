import SwiftUI

struct MissingPermissionView: View {
    
    var type: PermissionConstants.PermissionType
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ScrollView(showsIndicators: false) {
                VStack {
                    Image(systemName: "exclamationmark.transmission")
                        .font(.system(size: StyleConstants.mainScreenIconSize(for: size)))
                        .foregroundStyle(.blue)
                        .opacity(StyleConstants.mainScreenIconOpacity)
                    
                    if type == PermissionConstants.PermissionType.notifications {
                        Text("Unfortunately, CARWatch won't work when notifications are turned off. Please activate all notifications in the app settings.")
                            .font(.system(size: StyleConstants.explanationFontSize(for: size)))
                            .multilineTextAlignment(.center)
                    } else if type == PermissionConstants.PermissionType.camera {
                        Text("Unfortunately, CARWatch won't work when camera access is not granted. Please activate camera usage in the app settings.")
                            .font(.system(size: StyleConstants.explanationFontSize(for: size)))
                            .multilineTextAlignment(.center)
                    } else {
                        Text(verbatim: "Unknown Permission Type " + String(describing: type) + ".")
                    }
                    
                    Button("Go to App Settings"){
                        if let settings = PermissionConstants.appSettingsUrl {
                            UIApplication.shared.open(settings)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(StyleConstants.edgePadding(for: size))
                .frame(minHeight: size.height)
            }
        }
    }
}
    

#Preview {
    MissingPermissionView(type: PermissionConstants.PermissionType.camera)
}
