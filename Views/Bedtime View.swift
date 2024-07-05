import SwiftUI

struct BedtimeView: View {
    var body: some View {
        VStack {
            Image(systemName: "bed.double")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
                .opacity(0.3)
            Text("Good Evening")
                .font(.system(size: 30))
            Text("Are you going to bed?")
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
