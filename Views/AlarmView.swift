import SwiftUI
import AlertToast

struct AlarmView: View {
    @EnvironmentObject var avm: AlarmViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var alarmActive: Bool
    @State var alarmTime: Date
    @State private var showTimeToNextAlarmToast: Bool = false
    
    @Binding public var alarmsList: [String]
    @Binding public var alarmsScanned: [Bool]
    @State var alarmsActive: Bool = false
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
                    Toggle("", isOn: $alarmActive)
                        .labelsHidden()
                        .padding(StyleConstants.edgePadding)
                        .font(.system(size: StyleConstants.mainScreenFontSize))
                        .onChange(of: alarmActive, { _, _ in
                            toggleCurrentAlarm()
                        })
                } else {
                    Toggle("", isOn: $alarmActive)
                        .labelsHidden()
                        .padding(StyleConstants.edgePadding)
                        .font(.system(size: StyleConstants.mainScreenFontSize))
                        .onChange(of: alarmActive, perform: { _ in
                            toggleCurrentAlarm()
                        })
                }
                DatePicker("", selection: $alarmTime, displayedComponents: .hourAndMinute)
                    .onChange(of: alarmTime, perform: { _ in
                        avm.updateAlarmTime(time: alarmTime)
                        if(avm.alarm.isActive) {
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
                    ForEach(Array(alarmsList.enumerated()), id: \.1) {
                        index, alarm in
                        HStack{
                            Text("S\(index+1):")
                                .font(.system(size: StyleConstants.explanationFontSize))
                            Toggle("", isOn: $alarmsActive)
                                .labelsHidden()
                            Text(alarm)
                                .font(.system(size: StyleConstants.explanationFontSize))
                            if alarmsScanned[index] {
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
                let (diffHours, diffMinutes) = avm.getTimeUntilNextAlarm()
                let toastMsg = "Notification scheduled for\n\(diffHours) hours \(diffMinutes) minutes from now.\nPlease remember to set\nyour alarm clock accordingly!"
                let color = Color(UIColor.secondarySystemBackground)
                return AlertToast(displayMode: .banner(.slide), type: .complete(Color.green), title: toastMsg, style: .style(backgroundColor: color))
            }
            Spacer()
        }
    }
    
    func toggleCurrentAlarm(){
        avm.toggleCurrentAlarm()
        print("toggle alarm in view - \(avm.alarm.isActive)")
        if(avm.alarm.isActive) {
            showTimeToNextAlarmToast = true
        }
    }
}

#Preview {
    let avm = AlarmViewModel()
    @State var alarmsList = ["12:00", "13:00"]
    @State var alarmsScanned = [true, false]
    
    return AlarmView(alarmActive: avm.alarm.isActive, alarmTime: avm.alarm.time, alarmsList: $alarmsList, alarmsScanned: $alarmsScanned, alarmsActive: false).environmentObject(avm)
}
