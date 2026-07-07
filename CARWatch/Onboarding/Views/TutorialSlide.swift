import SwiftUI

struct TutorialSlide: View {
    let imageName : String
    let titleText : LocalizedStringKey
    let explanationText : LocalizedStringKey
    var showsSampleStatusSymbols: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let imageHeight = StyleConstants.onboardingImageHeight(for: size)
            let onboardingPadding = StyleConstants.onboardingPadding(for: size)
            let usesExpandedLayout = StyleConstants.isExpandedPadLayout(for: size)

            VStack(spacing: 0) {
                if usesExpandedLayout {
                    Spacer(minLength: StyleConstants.onboardingVerticalSpacingInset(for: size) * 0.5)
                }

                VStack(spacing: usesExpandedLayout ? 20 : 12) {
                    if !imageName.isEmpty{
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: imageHeight)
                            .cornerRadius(StyleConstants.roundedCornerRadius)
                            .shadow(radius: StyleConstants.shadowRadius)
                            .padding(onboardingPadding)
                            .accessibilityHidden(true)
                    } else {
                        Image("CarwatchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: imageHeight)
                            .padding(onboardingPadding)
                            .accessibilityHidden(true)
                    }
                    ScrollView {
                        VStack(spacing: 12) {
                            Text(titleText)
                                .font(.title.weight(.bold))
                                .accessibilityAddTraits(.isHeader)
                            if showsSampleStatusSymbols {
                                sampleStatusExplanationText
                                    .font(.system(size: StyleConstants.explanationFontSize(for: size)))
                            } else {
                                Text(explanationText)
                                    .font(.system(size: StyleConstants.explanationFontSize(for: size)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: StyleConstants.onboardingContentMaxWidth(for: size) ?? .infinity)
                .frame(maxWidth: .infinity)

                if usesExpandedLayout {
                    Spacer(minLength: StyleConstants.onboardingVerticalSpacingInset(for: size) * 0.5)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, onboardingPadding)
        }
    }

    private var sampleStatusExplanationText: Text {
        Text("The symbols next to the alarm time show whether a sample has been taken ")
            + Text(Image(systemName: "checkmark.circle")).foregroundColor(.green)
            + Text(" or was already due ")
            + Text(Image(systemName: "exclamationmark.arrow.circlepath")).foregroundColor(.orange)
            + Text(". Remaining samples are scheduled for later. Pressing the 'Take sample' button opens the barcode scanner for the respective sample.")
    }
}

#Preview {
    TutorialSlide(
        imageName: "sampleListSymbols",
        titleText: "Track your alarms",
        explanationText: "The symbols next to the alarm time show whether a sample has been taken (green checkmark) or was already due (orange exclamation mark). Remaining samples are scheduled for later. Pressing the 'Take sample' button opens the barcode scanner for the respective sample.",
        showsSampleStatusSymbols: true
    )
}
