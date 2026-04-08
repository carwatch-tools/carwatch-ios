import SwiftUI
import AlertToast

enum ActiveAlert {
    case toggleActivityAlert, takeSampleEarlyAlert
}

struct AlarmView: View {
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @Binding var initialAlarmTime: Date
    @Binding var isScannerPresented: Bool
    @Binding var currentAlarmId: Int?
    @Binding var scannerSource: ScannerPresentationSource?
    
    @State private var showToast: Bool = false
    @State private var showAlert: Bool = false
    @State private var showDisabledInfoAlert: Bool = false
    @State private var activeAlert: ActiveAlert = .toggleActivityAlert
    @State private var pendingToggleValue: Bool = false
    @State private var pendingToggleIndex: Int = 0

    private var isWakeupTimeSelectionDisabled: Bool {
        alarmVM.isAlarmOngoing() || alarmVM.isStudyFinished()
    }

    private var disabledWakeupMessage: LocalizedStringKey {
        alarmVM.isStudyFinished()
            ? "The study is already finished, so the wakeup time can no longer be changed."
            : "The wakeup time can only be changed after all samples for the current day have been recorded."
    }
    
    var body: some View {
        VStack {
            Image(systemName: "alarm")
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
            Text("Please set your desired wakeup time for tomorrow.")
                .font(.system(size: StyleConstants.mainScreenFontSize))
                .multilineTextAlignment(.center)
                .font(.system(size: StyleConstants.mainScreenFontSize))
            HStack {
                HStack{
                    Toggle("", isOn: Binding<Bool>(
                        get: { alarmVM.getInitialAlarm().isActive },
                        set: { newValue in
                            setInitialAlarmActivity(isActive: newValue)
                        }))
                    .labelsHidden()
                    .padding(StyleConstants.edgePadding)
                    .font(.system(size: StyleConstants.mainScreenFontSize))
                    DatePicker("", selection: $initialAlarmTime, displayedComponents: .hourAndMinute)
                        .onChange(of: initialAlarmTime, perform: { _ in
                            // backup old initial alarm value in case the selection is invalid
                            let backupTime = alarmVM.getInitialAlarm().time
                            alarmVM.updateAlarmTime(time: initialAlarmTime)
                            if let firstTimedAlarm = alarmVM.timedAlarms.first, initialAlarmTime > firstTimedAlarm.time {
                                // this can happen when using fixed time alarms, where the alarm times won't update depending on the initial alarm
                                initialAlarmTime = backupTime
                                alarmVM.updateAlarmTime(time: initialAlarmTime)
                            }
                            if(alarmVM.getInitialAlarm().isActive) {
                                showToast = true
                            }
                        })
                        .labelsHidden()
                        .scaledToFit()
                        .scaleEffect(CGSize(width: 1.5, height: 1.5))
                }
                .disabled(isWakeupTimeSelectionDisabled)

                if isWakeupTimeSelectionDisabled {
                    Button {
                        showDisabledInfoAlert = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Why is wakeup time disabled?")
                }
            }
            
            
            Divider()
                .padding(.bottom)
            ScrollView(showsIndicators: false, content: {
                VStack (alignment: .leading) {
                    Text("Saliva sample reminders")
                        .font(.system(size: StyleConstants.explanationFontSize))
                    ForEach(Array(alarmVM.timedAlarms.enumerated()), id: \.1) {
                        index, alarm in
                        HStack(alignment: .center, spacing: 12) {
                            HStack(alignment: .center, spacing: 8) {
                                Text("S\(alarm.getSalivaId(startSample: studyDataVM.studyData.startSample)):")
                                    .font(.system(size: StyleConstants.explanationFontSize))
                                    .frame(width: 40, alignment: .leading)

                                Toggle("", isOn: timedAlarmActivityBinding(index: index))
                                .labelsHidden()
                                .disabled(alarm.isScanned)
                                .frame(width: 50)

                                Color.clear
                                    .frame(width: 6)

                                Text(getHourMinFormattedString(time: alarm.time))
                                    .font(.system(size: StyleConstants.explanationFontSize))
                                    .frame(width: 78, alignment: .leading)
                            }
                            sampleTrailingColumn(for: alarm)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, StyleConstants.onboardingPadding)
            })
            .frame(maxWidth: .infinity)
            .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
                let color = Color(UIColor.secondarySystemBackground)
                let (diffHours, diffMinutes) = alarmVM.getTimeUntilNextInitialAlarm()
                let toastMsg = String(
                    format: String(localized: "Notification scheduled for\n%lld hours %lld minutes from now.\nPlease remember to set\nyour alarm clock accordingly!"),
                    Int64(diffHours),
                    Int64(diffMinutes)
                )
                return AlertToast(displayMode: .banner(.slide), type: .complete(Color.green), title: toastMsg, style: .style(backgroundColor: color))
                
            }
            .alert(isPresented: $showAlert) {
                switch activeAlert {
                case .takeSampleEarlyAlert:
                    return Alert(title: Text("This sample is scheduled for later. Are you sure you want to scan the sample now?"),
                                 primaryButton: .destructive(Text("Yes")) {
                        showAlert = false
                        scannerSource = .schedule
                        isScannerPresented = true
                    },
                                 secondaryButton: .cancel(Text("No")) {
                        currentAlarmId = nil
                        showAlert = false
                    }
                    )
                case .toggleActivityAlert:
                    return Alert(title: Text("This sample is required for the study. Are you sure to cancel this sample?"),
                                 primaryButton: .destructive(Text("Yes")) {
                        toggleTimedAlarm(index: pendingToggleIndex, isActive: !alarmVM.timedAlarmActivity[pendingToggleIndex])
                        showAlert = false
                    },
                                 secondaryButton: .cancel(Text("No")) {
                        showAlert = false
                    }
                    )
                }
            }
            .alert(String(localized: "Wakeup time unavailable"), isPresented: $showDisabledInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(disabledWakeupMessage)
            }
            Spacer()
        }
    }
    
    func setInitialAlarmActivity(isActive: Bool){
        alarmVM.setInitialAlarmActivity(isActive: isActive)
        if(alarmVM.getInitialAlarm().isActive) {
            alarmVM.updateAlarmTime(time: alarmVM.getInitialAlarm().time)
            // if initial alarm is activated, automatically activate all others
            for (index, _) in alarmVM.timedAlarms.enumerated() {
                alarmVM.setTimedAlarmActivity(index: index, isActive: isActive)
            }
            showToast = true
        }
    }
    
    func toggleTimedAlarm(index: Int, isActive: Bool){
        alarmVM.setTimedAlarmActivity(index: index, isActive: isActive)
    }

    private func timedAlarmActivityBinding(index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard alarmVM.timedAlarmActivity.indices.contains(index) else {
                    return false
                }
                return alarmVM.timedAlarmActivity[index]
            },
            set: { newValue in
                guard alarmVM.timedAlarmActivity.indices.contains(index) else {
                    return
                }

                pendingToggleValue = newValue
                pendingToggleIndex = index

                if newValue == false {
                    // only show alert when switching alarm off
                    activeAlert = .toggleActivityAlert
                    showAlert = true
                } else {
                    toggleTimedAlarm(index: pendingToggleIndex, isActive: !alarmVM.timedAlarmActivity[pendingToggleIndex])
                }
            }
        )
    }

    @ViewBuilder
    private func sampleTrailingContent(for alarm: Alarm) -> some View {
        if alarm.isScanned {
            Image(systemName: "checkmark.circle")
                .font(.system(size: StyleConstants.explanationFontSize))
                .foregroundStyle(.green)
        } else if alarm.isTriggered {
            Image(systemName: "exclamationmark.arrow.circlepath")
                .font(.system(size: StyleConstants.explanationFontSize))
                .foregroundStyle(.orange)
        } else {
            Button(action: {
                currentAlarmId = alarm.id
                if !alarm.isTriggered {
                    // alarm has not been triggered yet, which means the dedicated sampling time was not yet reached
                    activeAlert = .takeSampleEarlyAlert
                    showAlert = true
                } else {
                    // alarm is due alreadyon
                    scannerSource = .schedule
                    isScannerPresented = true
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "barcode.viewfinder")
                        .frame(width: 16, alignment: .center)
                    Text("Take sample")
                        .font(.system(size: StyleConstants.explanationFontSize))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .buttonStyle(.borderless)
            .disabled(!alarm.isActive)
        }
    }

    private var sampleTrailingReference: some View {
        HStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .frame(width: 16, alignment: .center)
            Text("Take sample")
                .font(.system(size: StyleConstants.explanationFontSize))
                .lineLimit(1)
        }
    }

    private func sampleTrailingColumn(for alarm: Alarm) -> some View {
        ZStack(alignment: .leading) {
            sampleTrailingReference
                .hidden()
            sampleTrailingContent(for: alarm)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct AlarmView_PreviewContainer: View {
    @State var initialAlarmTime: Date = getDateTomorrowMorning()
    @State var isScannerPresented: Bool = false
    @State var currentAlarmId: Int? = nil

    let alarmVM: AlarmViewModel = {
        let vm = AlarmViewModel()
        vm.initialAlarm = Alarm(id: AlarmConstants.initialAlarmId, isActive: false, isScanned: false, isTriggered: false)
        vm.timedAlarms = [
            Alarm(id: 0, isActive: false, isScanned: true, isTriggered: false),
            Alarm(id: 1, isActive: true, isScanned: false, isTriggered: true),
            Alarm(id: 2, isActive: true, isScanned: false, isTriggered: false)
        ]
        return vm
    }()

    var body: some View {
        AlarmView(
            initialAlarmTime: $initialAlarmTime,
            isScannerPresented: $isScannerPresented,
            currentAlarmId: $currentAlarmId,
            scannerSource: .constant(nil)
        )
        .environmentObject(alarmVM)
        .environmentObject(StudyDataViewModel())
    }
}

#Preview {
    AlarmView_PreviewContainer()
        .environment(\.locale, currentAppLocale())
}
