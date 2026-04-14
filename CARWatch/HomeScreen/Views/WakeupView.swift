import SwiftUI
import AlertToast

struct WakeupView: View {
    @AccessibilityFocusState private var isWakeupHeaderFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    private var shouldUseVerticalActionLayout: Bool {
        StyleConstants.isAccessibilitySize(dynamicTypeSize)
    }

    private func usesExpandedPadLayout(for size: CGSize) -> Bool {
        StyleConstants.isExpandedPadLayout(for: size)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let mainFontSize = StyleConstants.mainScreenFontSize(for: size)
            let iconSize = StyleConstants.mainScreenIconSize(for: size)
            let edgePadding = StyleConstants.edgePadding(for: size)
            let usesExpandedLayout = usesExpandedPadLayout(for: size)

            ScrollView(showsIndicators: false) {
                Group {
                    if usesExpandedLayout {
                        VStack(spacing: 28) {
                            VStack(spacing: 16) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: iconSize + 48))
                                    .foregroundStyle(.blue)
                                    .opacity(StyleConstants.mainScreenIconOpacity)
                                    .frame(width: 180, height: 180)
                                    .accessibilityHidden(true)

                                VStack(alignment: .center, spacing: 10) {
                                    Text("Good Morning")
                                        .font(.system(size: mainFontSize + 6, weight: .bold))
                                        .accessibilityAddTraits(.isHeader)
                                        .accessibilityFocused($isWakeupHeaderFocused)
                                    Text("Did you just wake up?")
                                        .font(.system(size: mainFontSize))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }

                            VStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    wakeupYesButton
                                    wakeupNoButton
                                }
                            }
                            .frame(maxWidth: 320, alignment: .leading)
                        }
                        .frame(maxWidth: 760, alignment: .leading)
                        .padding(.top, 12)
                        .padding(36)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        VStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.blue)
                                .opacity(StyleConstants.mainScreenIconOpacity)
                                .accessibilityHidden(true)
                            Text("Good Morning")
                                .font(.system(size: mainFontSize))
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($isWakeupHeaderFocused)
                            Text("Did you just wake up?")
                                .font(.system(size: mainFontSize))
                                .multilineTextAlignment(.center)
                            Group {
                                if shouldUseVerticalActionLayout {
                                    VStack(spacing: 12) {
                                        wakeupYesButton
                                        wakeupNoButton
                                    }
                                } else {
                                    HStack {
                                        wakeupYesButton
                                        wakeupNoButton
                                    }
                                }
                            }
                        }
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isWakeupHeaderFocused = true
            }
        }
        .onChange(of: showDelayedSampleAlert) { isPresented in
            if isPresented {
                postAccessibilityAnnouncement(
                    String(
                        format: localizedAppString("A delayed sample is planned. You will receive a reminder in %lld minutes."),
                        Int64(delayedSampleMinutes)
                    )
                )
            }
        }
        .onChange(of: showStudyFinishedAlert) { isPresented in
            if isPresented {
                postAccessibilityAnnouncement(localizedAppString("Study finished. Please export your logs and send them to your study contact email."))
            }
        }
    }
    
    private var wakeupYesButton: some View {
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
                initialAlarmTime = Date()
                alarmVM.confirmWakeup(at: initialAlarmTime)
                if alarmVM.isScanRequired() {
                    scannerSource = .wakeup
                    isScannerPresented = true
                } else if let nextTimedAlarm = alarmVM.getNextUpcomingAlarm() {
                    delayedSampleMinutes = max(
                        0,
                        Int(ceil(nextTimedAlarm.time.timeIntervalSince(initialAlarmTime) / 60))
                    )
                    showDelayedSampleAlert = true
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("wakeup.yes")
        .accessibilityLabel(localizedAppString("Yes, I just woke up"))
        .accessibilityHint(localizedAppString("Reports your wakeup and may open the scanner for the next sample."))
    }

    private var wakeupNoButton: some View {
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
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("wakeup.no")
        .accessibilityLabel(localizedAppString("No, I did not just wake up"))
        .accessibilityHint(localizedAppString("Keeps the wakeup report unchanged and shows a reminder if needed."))
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
