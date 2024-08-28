//
//  OnboardingAfterQrView.swift
//  CARWatch
//
//  Created by Admin on 28.08.24.
//

import SwiftUI

struct OnboardingAfterQrView: View {
    var body: some View {
        VStack {
            TabView {
                Text("due \(Image(systemName: "exclamationmark.arrow.circlepath")). Remaining")
                TutorialSlide(imageName: "CarwatchLogo", titleText: "Report waking up", explanationText: "You only need to report your awakening if you didn't set an alarm for the morning, or if you woke up before the alarm went off. Clicking the 'YES' button will schedule the sample alarms for the upcoming day.")
                TutorialSlide(imageName: "CarwatchLogo", titleText:"Track your alarms", explanationText: "You can set an alarm for the next morning directly from the alarm clock screen. Simply tap on the displayed time and choose your desired wake-up time. We recommend additionally setting an alarm in your usual alarm app for the same time.")
                TutorialSlide(imageName: "CarwatchLogo", titleText:"Track your alarms", explanationText: "The symbols next to the alarm time show whether a sample has been taken (green checkmark) or was already due \(Image(systemName: "exclamationmark.arrow.circlepath")). Remaining samples are scheduled for later. Pressing the 'Scan sample' button opens the barcode scanner for the respective sample.")
                TutorialSlide(imageName: "CarwatchLogo", titleText:"Report going to bed", explanationText: "In the bedtime screen, you can initiate the evening procedure before going to bed. You only need to do this if your study requires to take an evening sample. The 'LIGHTS OUT' button will activate the app's dark mode.")
                TutorialSlide(imageName: "CarwatchLogo", titleText: "Scan your sample", explanationText: "The barcode scanner opens automatically when you tap on a sample notification. After sampling, simply scan the barcode on the sample tube so that the sample can later be linked to the time of sampling.")
                TutorialSlide(imageName: "CarwatchLogo", titleText: "Start sampling!", explanationText: "The CARWatch app is now ready to go. To start the study, set the alarm for the next day or report your awakening in the morning. If you need to reconfigure the app or you want to do the tutorial again, press the respective entries in the top-right menu.")
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .border(Color.black)
            Button {
                
            } label: {
                Text("Next")
                    .padding(.horizontal, 50)
            }
            .padding(.bottom, 8)
            .buttonStyle(.borderedProminent)
            Button("Skip"){
                
            }
        }
    }
}


#Preview {
    OnboardingAfterQrView()
}
