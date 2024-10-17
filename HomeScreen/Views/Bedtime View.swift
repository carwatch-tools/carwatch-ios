import SwiftUI
import AlertToast

struct BedtimeView: View {
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @State var showToast: Bool = false
    @State var toastType: NotificationConstants.BedtimeToastType = .feedbackToast

    @State var isBarcodeScannerPresented : Bool = false
    @State var alarmId : String? = AlarmConstants.eveningAlarmId

    var body: some View {
        VStack {
            Image(systemName: "bed.double")
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
            Text("Good Evening")
                .font(.system(size: StyleConstants.mainScreenFontSize))
            Text("Are you going to bed?")
                .font(.system(size: StyleConstants.mainScreenFontSize))
                .multilineTextAlignment(.center)
            HStack{
                Button("YES") {
                    if studyDataVM.studyData.hasEveningSample {
                        if !alarmVM.isEveningScanned {
                            isBarcodeScannerPresented = true
                        } else {
                            toastType = .eveningSampleTakenToast
                            showToast = true
                        }
                    } else {
                        toastType = .feedbackToast
                        showToast = true
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("NO") {
                    toastType = .feedbackToast
                    showToast = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom)
            Button(alarmVM.isDarkModeOn ? "LIGHTS ON!" : "LIGHTS OUT!") {
                Logger.instance.log(tag: alarmVM.isDarkModeOn ? LoggerConstants.loggerActionLightsOn : LoggerConstants.loggerActionLightsOut, message: [String: Any]())
                alarmVM.isDarkModeOn.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.orange)
        }
        // TODO: continue from here
        .sheet(isPresented: $isBarcodeScannerPresented) {
            ScannerView(isPresented: $isBarcodeScannerPresented, alarmId: $alarmId, codeType: .ean8)
                .interactiveDismissDisabled()
                .environmentObject(alarmVM)
        }
        .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
            let color = Color(UIColor.secondarySystemBackground)
            switch toastType {
            case .feedbackToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: "Thank you for your feedback!", style: .style(backgroundColor: color))
            case .eveningSampleTakenToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: "You have already taken your evening sample.", style: .style(backgroundColor: color))
            }
        }
    }
}

#Preview {
    BedtimeView()
        .environmentObject(AlarmViewModel())
        .environmentObject(StudyDataViewModel())
}
