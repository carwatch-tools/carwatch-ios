import SwiftUI

struct BedtimeView: View {
    var body: some View {
        VStack {
            Image(systemName: "bed.double")
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
            Text("Good Evening")
                .font(.system(size: StyleConstants.mainScreenFontSize))
            Text("Are you going to bed?")
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
            .padding(.bottom)
            Button("LIGHTS OUT!") {
                // add some action
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.orange)
        }
    }
}

#Preview {
    BedtimeView()
}
