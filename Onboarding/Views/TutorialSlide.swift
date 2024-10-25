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
    TutorialSlide(imageName: "sampleListSymbols", titleText: "Some Title", explanationText: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
}
