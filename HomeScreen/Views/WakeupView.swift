import SwiftUI
import AlertToast

struct WakeupView: View {
    @EnvironmentObject var avm: AlarmViewModel
    
    @State var showToast: Bool = false
    @State var toastType: NotificationConstants.ToastType = .feedbackToast
    
    @Binding var initialAlarmTime: Date
    @Binding var isScannerPresented: Bool
    
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
                    // check if initial alarm was already triggered at current day -> wakeup can't be reported twice
                    if Calendar.current.isDate(avm.dateOfLastInitialAlarm, inSameDayAs: Date()) {
                        toastType = .wakeupReportedToast
                        showToast = true
                    } else if avm.isStudyFinished(){
                        toastType = .studyFinishedToast
                        showToast = true
                    } else {
                        // if possible, update initial alarm time to now
                        avm.updateAlarmTime(time: initialAlarmTime, scheduleInitialNotification: false)
                        avm.setInitialAlarmTriggered()
                        isScannerPresented = true
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("NO") {
                    toastType = .feedbackToast
                    showToast = true
                }
                .buttonStyle(.bordered)
            }
        }
        .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
            let color = Color(UIColor.secondarySystemBackground)
            switch toastType {
            case .feedbackToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: "Thank you for your feedback!", style: .style(backgroundColor: color))
            case .wakeupReportedToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: "You have already reported your wakeup.", style: .style(backgroundColor: color))
            case .studyFinishedToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: "You have already finished the study.", style: .style(backgroundColor: color))
            }
        }
    }
    
}

#Preview {
    @State var initialAlarmTime = Date()
    @State var isScannerPresented = false

    return WakeupView(initialAlarmTime: $initialAlarmTime, isScannerPresented: $isScannerPresented)
}
