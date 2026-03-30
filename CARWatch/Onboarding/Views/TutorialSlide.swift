import SwiftUI

struct TutorialSlide: View {
    let imageName : String
    let titleText : LocalizedStringKey
    let explanationText : LocalizedStringKey
    
    var body: some View {
            VStack {
                if !imageName.isEmpty{
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: StyleConstants.onboardingImageHeight)
                        .cornerRadius(StyleConstants.roundedCornerRadius)
                        .shadow(radius: StyleConstants.shadowRadius)
                        .padding(StyleConstants.onboardingPadding)
                } else {
                    Image("CarwatchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: StyleConstants.onboardingImageHeight)
                        .padding(StyleConstants.onboardingPadding)
                }
                ScrollView {
                    Text(titleText)
                        .font(.title.weight(.bold))
                    Text(explanationText)
                }
                Spacer()
            }
            .padding([.leading, .trailing])
        }
}

#Preview {
    TutorialSlide(
        imageName: "sampleListSymbols",
        titleText: "Track your alarms",
        explanationText: "The symbols next to the alarm time show whether a sample has been taken (green checkmark) or was already due (orange exclamation mark). Remaining samples are scheduled for later. Pressing the 'Scan sample' button opens the barcode scanner for the respective sample."
    )
}
