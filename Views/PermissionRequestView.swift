import SwiftUI

struct PermissionRequestView: View {
    @EnvironmentObject var uvm: UserDataViewModel
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.transmission")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
                .opacity(0.3)
            Text("Unfortunately, CARWatch won't work when Notification Permission is not granted.")
                .font(.system(size: 30))
                .multilineTextAlignment(.center)
            Button("Grant Permission now"){
                //NotificationManager.instance.reloadAuthorizationStatus(completion: <#T##(Bool) -> ()#>)
                
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    PermissionRequestView()
    
}
