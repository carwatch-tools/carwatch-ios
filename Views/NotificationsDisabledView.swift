import SwiftUI

struct NotificationsDisabledView: View {
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.transmission")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
                .opacity(0.3)
            Text("Unfortunately, CARWatch won't work when Notifications are turned off. Please activate all Notifications in the app settings.")
                .font(.system(size: 20))
                .multilineTextAlignment(.center)
            Button("Go to App Settings"){
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settings)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}

#Preview {
    NotificationsDisabledView()
    
}
