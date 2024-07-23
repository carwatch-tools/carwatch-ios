import SwiftUI

struct WakeupView: View {
    var body: some View {
        VStack {
            Image(systemName: "sun.max.fill")
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
            Text("Good Morning")
                .font(.system(size: StyleConstants.mainScreenFontSize))
            Text("Did you just wake up?")
                .font(.system(size: StyleConstants.mainScreenFontSize))
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
