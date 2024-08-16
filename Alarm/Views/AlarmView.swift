import SwiftUI
import AlertToast

struct AlarmView: View {
    @EnvironmentObject var avm: AlarmViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var initialAlarmActive: Bool
    @State var initialAlarmTime: Date
    @State var timedAlarmActive: [Bool]
    
    @State private var showTimeToNextAlarmToast: Bool = false
    
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
                if #available(iOS 17.0, *) {
                    // signature of onChange function was updated
                    Toggle("", isOn: $initialAlarmActive)
                        .labelsHidden()
                        .padding(StyleConstants.edgePadding)
                        .font(.system(size: StyleConstants.mainScreenFontSize))
                        .onChange(of: initialAlarmActive, { _, _ in
                            toggleInitialAlarm()
                        })
                } else {
                    Toggle("", isOn: $initialAlarmActive)
                        .labelsHidden()
                        .padding(StyleConstants.edgePadding)
                        .font(.system(size: StyleConstants.mainScreenFontSize))
                        .onChange(of: initialAlarmActive, perform: { _ in
                            toggleInitialAlarm()
                        })
                }
                DatePicker("", selection: $initialAlarmTime, displayedComponents: .hourAndMinute)
                    .onChange(of: initialAlarmTime, perform: { _ in
                        avm.updateAlarmTime(time: initialAlarmTime)
                        if(avm.initialAlarm.isActive) {
                            showTimeToNextAlarmToast = true
                        }
                    })
                    .labelsHidden()
                    .scaledToFit()
                    .scaleEffect(CGSize(width: 1.5, height: 1.5))
            }
            
            Divider()
                .padding(.bottom)
            ScrollView(showsIndicators: false, content: {
                VStack (alignment: .leading) {
                    Text("Saliva sample reminders")
                        .font(.system(size: StyleConstants.explanationFontSize))
                    ForEach(Array(avm.timedAlarms.enumerated()), id: \.1) {
                        index, alarm in
                        HStack{
                            Text("S\(alarm.salivaId):")
                                .font(.system(size: StyleConstants.explanationFontSize))
                            if #available(iOS 17.0, *) {
                                // signature of onChange function was updated
                                Toggle("", isOn: $timedAlarmActive[index])
                                    .labelsHidden()
                                    .onChange(of: timedAlarmActive[index], { _, _ in
                                        toggleTimedAlarm(index: index)
                                    })
                            } else {
                                Toggle("", isOn: $timedAlarmActive[index])
                                    .labelsHidden()
                                    .onChange(of: timedAlarmActive[index], perform: { _ in
                                        toggleTimedAlarm(index: index)
                                    })
                            }
                            Text(getHourMinFormattedString(time: alarm.time))
                                .font(.system(size: StyleConstants.explanationFontSize))
                            if alarm.isScanned {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: StyleConstants.explanationFontSize))
                                    .foregroundStyle(.green)
                                    .padding(.leading, 2)
                            } else {
                                Button(action: {
                                    // change to scan view
                                    print("scan button pressed")
                                })
                                {
                                    Label("Take sample", systemImage: "barcode.viewfinder")
                                        .font(.system(size: StyleConstants.explanationFontSize))
                                }
                                .buttonStyle(.borderless)
                                
                            }
                        }
                    }
                }
            })
            .frame(maxWidth: .infinity)
            .toast(isPresenting: $showTimeToNextAlarmToast, duration: StyleConstants.alertDuration) {
                let (diffHours, diffMinutes) = avm.getTimeUntilNextInitialAlarm()
                let toastMsg = "Notification scheduled for\n\(diffHours) hours \(diffMinutes) minutes from now.\nPlease remember to set\nyour alarm clock accordingly!"
                let color = Color(UIColor.secondarySystemBackground)
                return AlertToast(displayMode: .banner(.slide), type: .complete(Color.green), title: toastMsg, style: .style(backgroundColor: color))
            }
            Spacer()
        }
    }
    
    func toggleInitialAlarm(){
        avm.toggleInitialAlarm()
        print("toggle initial alarm in view - \(avm.initialAlarm.isActive)")
        if(avm.initialAlarm.isActive) {
            showTimeToNextAlarmToast = true
        }
    }
    
    func toggleTimedAlarm(index: Int){
        avm.toggleTimedAlarm(index: index)
    }
}

#Preview {
    let avm = AlarmViewModel()
    
    return AlarmView(initialAlarmActive: avm.initialAlarm.isActive, initialAlarmTime: avm.initialAlarm.time, timedAlarmActive: [Bool](repeating: false, count: avm.timedAlarms.count)).environmentObject(avm)
}
