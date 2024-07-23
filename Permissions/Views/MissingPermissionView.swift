import SwiftUI

struct MissingPermissionView: View {
    
    var type: PermissionConstants.PermissionType
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.transmission")
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
            
            if type == PermissionConstants.PermissionType.notifications {
                Text("Unfortunately, CARWatch won't work when notifications are turned off. Please activate all notifications in the app settings.")
                    .font(.system(size: StyleConstants.explanationFontSize))
                    .multilineTextAlignment(.center)
            } else if type == PermissionConstants.PermissionType.camera {
                Text("Unfortunately, CARWatch won't work when camera access is not granted. Please activate camera usage in the app settings.")
                    .font(.system(size: StyleConstants.explanationFontSize))
                    .multilineTextAlignment(.center)
            } else {
                Text("Unknown Permission Type \(type).")
            }
            
            Button("Go to App Settings"){
                if let settings = PermissionConstants.appSettingsUrl {
                    UIApplication.shared.open(settings)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(StyleConstants.edgePadding)
    }
}

#Preview {
    MissingPermissionView(type: PermissionConstants.PermissionType.camera)
}
