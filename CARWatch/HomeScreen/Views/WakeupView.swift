import SwiftUI
import AlertToast

struct WakeupView: View {
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel

    @State var showToast: Bool = false
    @State var toastType: NotificationConstants.WakeupToastType = .feedbackToast
    @State private var delayedSampleMinutes: Int = 0
    @State private var showDelayedSampleAlert: Bool = false
    @State private var showStudyFinishedAlert: Bool = false
    
    @Binding var initialAlarmTime: Date
    @Binding var isScannerPresented: Bool
    @Binding var scannerSource: ScannerPresentationSource?
    var onDelayedSampleAcknowledged: () -> Void = {}
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let mainFontSize = StyleConstants.mainScreenFontSize(for: size)
            let iconSize = StyleConstants.mainScreenIconSize(for: size)
            let edgePadding = StyleConstants.edgePadding(for: size)

            ScrollView(showsIndicators: false) {
                VStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.blue)
                        .opacity(StyleConstants.mainScreenIconOpacity)
                    Text("Good Morning")
                        .font(.system(size: mainFontSize))
                    Text("Did you just wake up?")
                        .font(.system(size: mainFontSize))
                        .multilineTextAlignment(.center)
                    HStack{
                        Button("YES") {
                            if alarmVM.isStudyFinished(){
                                showStudyFinishedAlert = true
                                return
                            }
                            if Calendar.current.isDate(alarmVM.dateOfLastInitialAlarm, inSameDayAs: Date()) {
                                toastType = .wakeupReportedToast
                                showToast = true
                            } else {
                                var msg = [String: Any]()
                                msg[LoggerConstants.loggerExtraAlarmId] = AlarmConstants.initialAlarmId
                                Logger.instance.log(tag: LoggerConstants.loggerActionSpontaneousAwakening, message: msg)
                                alarmVM.setInitialAlarmActivity(isActive: true)
                                for (index, _) in alarmVM.timedAlarms.enumerated() {
                                    alarmVM.setTimedAlarmActivity(index: index, isActive: true)
                                }
                                initialAlarmTime = Date()
                                alarmVM.updateAlarmTime(time: initialAlarmTime, scheduleInitialNotification: false)
                                alarmVM.setInitialAlarmTriggered()
                                if alarmVM.triggerWakeupSampleIfNeeded() != nil {
                                    scannerSource = .wakeup
                                    isScannerPresented = true
                                } else if let firstTimedAlarm = alarmVM.timedAlarms.first {
                                    delayedSampleMinutes = max(
                                        1,
                                        Int(firstTimedAlarm.time.timeIntervalSince(initialAlarmTime).rounded() / 60)
                                    )
                                    showDelayedSampleAlert = true
                                }
                            }
                        }
                    .buttonStyle(.borderedProminent)
                    Button("NO") {
                        if alarmVM.isStudyFinished() {
                            showStudyFinishedAlert = true
                            return
                        }

                        let wakeupAlreadyReportedToday = Calendar.current.isDate(alarmVM.dateOfLastInitialAlarm, inSameDayAs: Date())
                        toastType = !wakeupAlreadyReportedToday ? .wakeupReminderToast : .feedbackToast
                        showToast = true
                    }
                    .buttonStyle(.bordered)
                }
                }
                .padding(edgePadding)
                .frame(minHeight: size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear.ignoresSafeArea())
        }
        .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
            let color = Color(UIColor.secondarySystemBackground)
            switch toastType {
            case .feedbackToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("Thank you for your feedback!"), style: .style(backgroundColor: color))
            case .wakeupReminderToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("Please remember to take your sample\nwhen you wake up."), style: .style(backgroundColor: color))
            case .wakeupReportedToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("You have already reported your wakeup."), style: .style(backgroundColor: color))
            case .delayedSampleToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: "", style: .style(backgroundColor: color))
            }
        }
        .alert(localizedAppString("Delayed sample planned"), isPresented: $showDelayedSampleAlert) {
            Button("OK", role: .cancel) {
                onDelayedSampleAcknowledged()
            }
        } message: {
            Text(
                String(
                    format: localizedAppString("A delayed sample is planned for your study. You will receive a reminder to take that sample in %lld minutes."),
                    Int64(delayedSampleMinutes)
                )
            )
        }
        .alert(localizedAppString("Study Finished"), isPresented: $showStudyFinishedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localizedAppString("You have already finished the study.\nThanks for participating!\nPlease export your logs and send them to your study contact email."))
        }
    }
    
}

#Preview {
    let alarmVM = AlarmViewModel()

    return WakeupView(
        initialAlarmTime: .constant(Date()),
        isScannerPresented: .constant(false),
        scannerSource: .constant(nil),
        onDelayedSampleAcknowledged: {}
    )
    .environmentObject(alarmVM)
    .environmentObject(StudyDataViewModel())
}
