import SwiftUI

struct TutorialView: View {
    
    @EnvironmentObject var svm: SessionViewModel
    
    @State var pageIndex: Int = 0
    
    var imageNames: [String] = ["CarwatchLogo", "CarwatchLogo", "CarwatchLogo", "CarwatchLogo", "CarwatchLogo", "CarwatchLogo"]
    var titleTexts: [String] = ["Report waking up", "Track your alarms", "Track your alarms", "Report going to bed", "Scan your sample", "Start sampling!"]
    var explanationTexts: [String] = ["You only need to report your awakening if you didn't set an alarm for the morning, or if you woke up before the alarm went off. Clicking the 'YES' button will schedule the sample alarms for the upcoming day.", "You can set an alarm for the next morning directly from the alarm clock screen. Simply tap on the displayed time and choose your desired wake-up time. We recommend additionally setting an alarm in your usual alarm app for the same time.", "The symbols next to the alarm time show whether a sample has been taken (green checkmark) or was already due (orange exclamation mark). Remaining samples are scheduled for later. Pressing the 'Scan sample' button opens the barcode scanner for the respective sample.", "In the bedtime screen, you can initiate the evening procedure before going to bed. You only need to do this if your study requires to take an evening sample. The 'LIGHTS OUT' button will activate the app's dark mode.", "The barcode scanner opens automatically when you tap on a sample notification. After sampling, simply scan the barcode on the sample tube so that the sample can later be linked to the time of sampling.", "The CARWatch app is now ready to go. To start the study, set the alarm for the next day or report your awakening in the morning. If you need to reconfigure the app or you want to do the tutorial again, press the respective entries in the top-right menu."]
    
    var body: some View {
        VStack {
            TabView(selection: $pageIndex) {
                ForEach(Array(zip(imageNames, zip(titleTexts, explanationTexts)).enumerated()), id: \.0) { index, data in
                    let (imageName, (titleText, explanationText)) = data
                    TutorialSlide(imageName: imageName, titleText: titleText, explanationText: explanationText)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            if (pageIndex == titleTexts.count - 1) {
                Button("Get Started") {
                    svm.startStudy()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            } else {
                Button("Skip") {
                    svm.startStudy()
                }
                .buttonStyle(.borderless)
                .padding()
            }
        }
    }
}


#Preview {
    TutorialView().environmentObject(SessionViewModel())
}
