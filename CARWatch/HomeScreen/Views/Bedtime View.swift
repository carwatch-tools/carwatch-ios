import SwiftUI
import AlertToast

struct BedtimeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @State var showToast: Bool = false
    @State var toastType: NotificationConstants.BedtimeToastType = .feedbackToast

    @State var isBarcodeScannerPresented : Bool = false
    @State var alarmId : Int? = AlarmConstants.eveningAlarmId
    @State private var showStudyFinishedAlert: Bool = false

    private var isDarkModeEnabled: Bool {
        alarmVM.isDarkModeOn ?? (colorScheme == .dark)
    }

    private var bedtimeBackgroundColor: Color {
        isDarkModeEnabled ? .black : .white
    }

    private var bedtimeForegroundColor: Color {
        isDarkModeEnabled ? .white : .black
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let mainFontSize = StyleConstants.mainScreenFontSize(for: size)
            let iconSize = StyleConstants.mainScreenIconSize(for: size)
            let edgePadding = StyleConstants.edgePadding(for: size)

            ScrollView(showsIndicators: false) {
                VStack {
                    Image(systemName: "bed.double")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.blue)
                        .opacity(StyleConstants.mainScreenIconOpacity)
                    Text("Good Evening")
                        .font(.system(size: mainFontSize))
                    Text("Are you going to bed?")
                        .font(.system(size: mainFontSize))
                        .multilineTextAlignment(.center)
                    HStack{
                        Button("YES") {
                            if studyDataVM.studyData.hasEveningSample {
                                if !alarmVM.isEveningScanned {
                                    isBarcodeScannerPresented = true
                                } else if alarmVM.isStudyFinished() {
                                    showStudyFinishedAlert = true
                                } else {
                                    toastType = .eveningSampleTakenToast
                                    showToast = true
                                }
                            } else {
                                toastType = .noEveningSampleToast
                                showToast = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("NO") {
                            if alarmVM.isStudyFinished() {
                                showStudyFinishedAlert = true
                                return
                            }

                            toastType = studyDataVM.studyData.hasEveningSample ? .bedtimeReminderToast : .noSampleTonightToast
                            showToast = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.bottom)
                    Button(isDarkModeEnabled ? "LIGHTS ON!" : "LIGHTS OUT!") {
                        Logger.instance.log(tag: isDarkModeEnabled ? LoggerConstants.loggerActionLightsOn : LoggerConstants.loggerActionLightsOut, message: [String: Any]())
                        alarmVM.isDarkModeOn = !isDarkModeEnabled
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.orange)
                }
                .padding(edgePadding)
                .frame(minHeight: size.height)
                .foregroundStyle(bedtimeForegroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bedtimeBackgroundColor.ignoresSafeArea())
        }
        .sheet(isPresented: $isBarcodeScannerPresented) {
            ScannerView(isPresented: $isBarcodeScannerPresented, alarmId: $alarmId, codeType: .ean8)
                .interactiveDismissDisabled()
                .environmentObject(alarmVM)
        }
        .onChange(of: isBarcodeScannerPresented) { isPresented in
            if !isPresented && alarmVM.isStudyFinished() {
                showStudyFinishedAlert = true
            }
        }
        .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
            let color = Color(UIColor.secondarySystemBackground)
            switch toastType {
            case .feedbackToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("Thank you for your feedback!"), style: .style(backgroundColor: color))
            case .bedtimeReminderToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("Remember to take your sample\nright before going to bed."), style: .style(backgroundColor: color))
            case .noSampleTonightToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("Tonight no sample is required."), style: .style(backgroundColor: color))
            case .noEveningSampleToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("Your study does not require an evening sample.\nGood night!"), style: .style(backgroundColor: color))
            case .eveningSampleTakenToast:
                return AlertToast(displayMode: .banner(.slide), type: .regular, title: localizedAppString("You have already taken your evening sample.\nGood night!"), style: .style(backgroundColor: color))
            }
        }
        .alert(localizedAppString("Study Finished"), isPresented: $showStudyFinishedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localizedAppString("This was your last sample.\nThank you for participating in the study!\nPlease export your logs and send them\nto your study contact email."))
        }
    }
}

#Preview {
    BedtimeView()
        .environmentObject(AlarmViewModel())
        .environmentObject(StudyDataViewModel())
}
