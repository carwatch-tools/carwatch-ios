import SwiftUI

struct TutorialView: View {
    @EnvironmentObject var sessionVM: SessionViewModel

    let isPresentedFromOngoingStudy: Bool

    @State var pageIndex: Int = 0
    
    var imageNames: [String] = ["wakeup", "schedule", "sampleListSymbols", "bedtime", "scan", "export_logs", ""]
    var titleTexts: [LocalizedStringKey] = ["Report waking up", "Track your alarms", "Track your alarms", "Report going to bed", "Scan your sample", "Export your logs", "Start sampling!"]
    var explanationTexts: [LocalizedStringKey] = ["Report your wakeup when you wake up, especially if you woke up before your alarm or did not use the CARWatch alarm. After wakeup is recorded, CARWatch calculates and schedules the samples for the active study day.", "You can set a wakeup alarm for the next morning directly from the alarm clock screen. Simply tap on the displayed time and choose your desired wake-up time.", "The symbols show the sample status: recorded (green checkmark), overdue (orange symbol), or missed after the study day was finished (red X). Future samples are shown without warning symbols. Pressing the 'Take sample' button opens the barcode scanner for the respective sample.", "Use the bedtime screen before going to sleep. If your study requires an evening sample, CARWatch will guide you through it. If daytime samples are still open, CARWatch may ask whether they should be marked as missed before finishing the study day.", "The barcode scanner opens automatically when you tap on a sample notification. After sampling, simply scan the barcode on the sample tube so that the sample can later be linked to the time of sampling.", "After your study is completed, open the menu in the top-right corner and choose 'Share Logs'. Then send the exported logs to your study contact email.", "CARWatch is ready. To start the study, set your wakeup alarm for tomorrow or report your wakeup in the morning. You can review the tutorial or reconfigure the app from the top-right menu."]

    private var isLastPage: Bool {
        pageIndex == titleTexts.count - 1
    }

    private var actionButtonTitle: LocalizedStringKey {
        if isPresentedFromOngoingStudy {
            return isLastPage ? "Back to Ongoing Study" : "Skip"
        }
        return isLastPage ? "Get Started" : "Skip"
    }

    private func completeTutorial() {
        if isPresentedFromOngoingStudy {
            sessionVM.dismissInStudyTutorial()
        } else {
            sessionVM.startStudy()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(zip(imageNames, zip(titleTexts, explanationTexts)).enumerated()), id: \.0) { index, data in
                        let (imageName, (titleText, explanationText)) = data
                        TutorialSlide(
                            imageName: imageName,
                            titleText: titleText,
                            explanationText: explanationText,
                            showsSampleStatusSymbols: index == 2
                        )
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .accessibilityLabel(localizedAppString("Tutorial pages"))
                .accessibilityValue("\(pageIndex + 1) of \(titleTexts.count)")

                Button(actionButtonTitle) {
                    completeTutorial()
                }
                .frame(maxWidth: StyleConstants.onboardingContentMaxWidth(for: size) ?? .infinity)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, StyleConstants.edgePadding(for: size))
                .padding(.top, StyleConstants.isExpandedPadLayout(for: size) ? 20 : 0)
                .padding(.bottom, StyleConstants.isExpandedPadLayout(for: size) ? 32 : 16)
                .buttonStyle(.borderedProminent)
                .tint(isLastPage ? Color.accentColor : Color.clear)
                .foregroundStyle(isLastPage ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.accentColor))
                .accessibilityIdentifier(isLastPage ? (isPresentedFromOngoingStudy ? "tutorial.backToStudy" : "tutorial.getStarted") : "tutorial.skip")
                .accessibilityHint(localizedAppString(isPresentedFromOngoingStudy ? "Closes the tutorial and returns to the ongoing study." : (isLastPage ? "Starts the study." : "Skips the tutorial and starts the study.")))
            }
        }
    }
}


#Preview {
    TutorialView(isPresentedFromOngoingStudy: false).environmentObject(SessionViewModel())
}
