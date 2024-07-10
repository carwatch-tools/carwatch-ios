import SwiftUI
import AlertToast

struct AlarmView: View {
    @EnvironmentObject var avm: AlarmViewModel
    
    @State var alarmActive: Bool
    @State var alarmTime: Date
    @State private var showTimeToNextAlarmToast: Bool = false
    
    @Binding public var alarmsList: [String]
    @State var alarmsActive: Bool = false
    var body: some View {
        VStack {
            Image(systemName: "alarm")
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
            Text("Please set your desired alarm time for tomorrow.")
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
                            avm.toggleCurrentAlarm()
                        })
                } else {
                    Toggle("", isOn: $alarmActive)
                        .labelsHidden()
                        .padding(StyleConstants.edgePadding)
                        .font(.system(size: StyleConstants.mainScreenFontSize))
                        .onChange(of: alarmActive, perform: { _ in
                            avm.toggleCurrentAlarm()
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
                Text("Saliva sample alarms")
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
                        Button(action: {
                            // change to scan view
                            print("scan button pressed")
                        })
                        {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: StyleConstants.explanationFontSize))
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.bordered)
                        Button(action: {
                            // TODO: figure out what this button does
                            print("repeat button pressed")
                        }) {
                            Image(systemName: "repeat")
                                .font(.system(size: StyleConstants.explanationFontSize))
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            })
            .frame(maxWidth: .infinity)
            .toast(isPresenting: $showTimeToNextAlarmToast) {
                let (diffHours, diffMinutes) = avm.getTimeUntilNextAlarm()
                let toastMsg = "Notification scheduled for \n \(diffHours) hours \(diffMinutes) minutes from now."
                return AlertToast(displayMode: .hud, type: .complete(Color.green), title: toastMsg)
            }
            Spacer()
        }
    }
}

#Preview {
    var avm = AlarmViewModel()
    @State var alarmsList = ["12:00", "13:00"]
    
    return AlarmView(alarmActive: avm.alarm.isActive, alarmTime: avm.alarm.time, alarmsList: $alarmsList, alarmsActive: false).environmentObject(avm)
}
