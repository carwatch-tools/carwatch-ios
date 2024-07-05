import SwiftUI

struct WakeupView: View {
    var body: some View {
        VStack {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
                .opacity(0.3)
            Text("Good Morning")
                .font(.system(size: 30))
            Text("Did you just wake up?")
                .font(.system(size: 30))
                .multilineTextAlignment(.center)
            HStack{
                Button("YES") {
                    // add some action
                }
                .buttonStyle(.borderedProminent)
                Button("NO") {
                    // add some action
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    WakeupView()
}
