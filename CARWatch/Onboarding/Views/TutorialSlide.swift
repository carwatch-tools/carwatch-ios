import SwiftUI

struct TutorialSlide: View {
    let imageName : String
    let titleText : LocalizedStringKey
    let explanationText : LocalizedStringKey
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let imageHeight = StyleConstants.onboardingImageHeight(for: size)
            let onboardingPadding = StyleConstants.onboardingPadding(for: size)

            VStack {
                if !imageName.isEmpty{
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: imageHeight)
                        .cornerRadius(StyleConstants.roundedCornerRadius)
                        .shadow(radius: StyleConstants.shadowRadius)
                        .padding(onboardingPadding)
                } else {
                    Image("CarwatchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: imageHeight)
                        .padding(onboardingPadding)
                }
                ScrollView {
                    VStack(spacing: 12) {
                        Text(titleText)
                            .font(.title.weight(.bold))
                        Text(explanationText)
                            .font(.system(size: StyleConstants.explanationFontSize(for: size)))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .padding(.horizontal, onboardingPadding)
        }
    }
}

#Preview {
    TutorialSlide(
        imageName: "sampleListSymbols",
        titleText: "Track your alarms",
        explanationText: "The symbols next to the alarm time show whether a sample has been taken (green checkmark) or was already due (orange exclamation mark). Remaining samples are scheduled for later. Pressing the 'Scan sample' button opens the barcode scanner for the respective sample."
    )
}
