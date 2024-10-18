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
    
    @State private var showToast: Bool = false
    @State private var showAlert: Bool = false
    @State private var activeAlert: ActiveAlert = .toggleActivityAlert
    @State private var pendingToggleValue: Bool = false
    @State private var pendingToggleIndex: Int = 0
    
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
            HStack{
                Toggle("", isOn: Binding<Bool>(
                    get: { alarmVM.timedAlarmActivity[0] },
                    set: { newValue in
                        setInitialAlarmActivity(isActive: newValue)
                    }))
                .labelsHidden()
                .padding(StyleConstants.edgePadding)
                .font(.system(size: StyleConstants.mainScreenFontSize))
                DatePicker("", selection: $initialAlarmTime, displayedComponents: .hourAndMinute)
                    .onChange(of: initialAlarmTime, perform: { _ in
                        alarmVM.updateAlarmTime(time: initialAlarmTime)
                        if(alarmVM.getInitialAlarm().isActive) {
                            showToast = true
                        }
                    })
                    .labelsHidden()
                    .scaledToFit()
                    .scaleEffect(CGSize(width: 1.5, height: 1.5))
            }.disabled(alarmVM.isAlarmOngoing() || alarmVM.isStudyFinished())
            
            
            Divider()
                .padding(.bottom)
            ScrollView(showsIndicators: false, content: {
                VStack (alignment: .leading) {
                    Text("Saliva sample reminders")
                        .font(.system(size: StyleConstants.explanationFontSize))
                    ForEach(Array(alarmVM.timedAlarms.enumerated()), id: \.1) {
                        index, alarm in
                        HStack{
                            Text("S\(alarm.getSalivaId(startSample: studyDataVM.studyData.startSample)):")
                                .font(.system(size: StyleConstants.explanationFontSize))
                            Toggle("", isOn: Binding<Bool>(
                                get: { alarmVM.timedAlarmActivity[index] },
                                set: { newValue in
                                    pendingToggleValue = newValue
                                    pendingToggleIndex = index
                                    if newValue == false {
                                        // only show alert when switching alarm off
                                        activeAlert = .toggleActivityAlert
                                        showAlert = true
                                    } else {
                                        toggleTimedAlarm(index: pendingToggleIndex, isActive: !alarmVM.timedAlarmActivity[pendingToggleIndex])
                                    }
                                }))
                            .labelsHidden()
                            .disabled(alarm.isScanned)
                            Text(getHourMinFormattedString(time: alarm.time))
                                .font(.system(size: StyleConstants.explanationFontSize))
                            if alarm.isScanned {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: StyleConstants.explanationFontSize))
                                    .foregroundStyle(.green)
                                    .padding(.leading, 2)
                            } else {
                                HStack {
                                    Button(action: {
                                        currentAlarmId = alarm.id
                                        if !alarm.isTriggered {
                                            // alarm has not been triggered yet, which means the dedicated sampling time was not yet reached
                                            activeAlert = .takeSampleEarlyAlert
                                            showAlert = true
                                        } else {
                                            // alarm is due alreadyon
                                            isScannerPresented = true
                                        }
                                    })
                                    {
                                        Label("Take sample", systemImage: "barcode.viewfinder")
                                            .font(.system(size: StyleConstants.explanationFontSize))
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(!alarm.isActive)
                                    if alarm.isTriggered && !alarm.isScanned {
                                        Image(systemName: "exclamationmark.arrow.circlepath")
                                            .font(.system(size: StyleConstants.explanationFontSize))
                                            .foregroundStyle(.orange)
                                            .padding(.leading, 2)
                                    }
                                }
                                
                            }
                        }
                    }
                }
            })
            .frame(maxWidth: .infinity)
            .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
                let color = Color(UIColor.secondarySystemBackground)
                let (diffHours, diffMinutes) = alarmVM.getTimeUntilNextInitialAlarm()
                let toastMsg = "Notification scheduled for\n\(diffHours) hours \(diffMinutes) minutes from now.\nPlease remember to set\nyour alarm clock accordingly!"
                return AlertToast(displayMode: .banner(.slide), type: .complete(Color.green), title: toastMsg, style: .style(backgroundColor: color))
                
            }
            .alert(isPresented: $showAlert) {
                switch activeAlert {
                case .takeSampleEarlyAlert:
                    return Alert(title: Text("This sample is scheduled for later. Are you sure you want to scan the sample now?"),
                                 primaryButton: .destructive(Text("Yes")) {
                        showAlert = false
                        isScannerPresented = true
                    },
                                 secondaryButton: .cancel(Text("No")) {
                        currentAlarmId = nil
                        showAlert = false
                    }
                    )
                case .toggleActivityAlert:
                    return Alert(title: Text("This alarm is required for the study. Are you sure to cancel this alarm?"),
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
}

#Preview {
    @State var isScannerPresented: Bool = false
    @State var currentAlarmId: Int? = nil
    @State var initialAlarmTime = Date()
    let avm = AlarmViewModel()
    
    return AlarmView(initialAlarmTime: $initialAlarmTime, isScannerPresented: $isScannerPresented, currentAlarmId: $currentAlarmId).environmentObject(avm).environmentObject(StudyDataViewModel())
}
