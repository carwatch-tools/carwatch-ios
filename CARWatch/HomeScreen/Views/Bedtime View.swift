import SwiftUI
import AlertToast

struct BedtimeView: View {
    @AccessibilityFocusState private var isBedtimeHeaderFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @State var showToast: Bool = false
    @State var toastType: NotificationConstants.BedtimeToastType = .feedbackToast

    @Binding var isScannerPresented: Bool
    @Binding var alarmId: Int?
    @Binding var scannerSource: ScannerPresentationSource?
    @Binding var selectedTab: Int
    @Binding var finishedStudyDayToDisplay: Int?
    @State private var showStudyFinishedAlert: Bool = false
    @State private var showRemainingSamplesAlert: Bool = false
    @State private var pendingFinishAfterEveningSample = false
    @State private var pendingMissedTimedAlarmsSnapshot: [Alarm]? = nil
    private var isDarkModeEnabled: Bool {
        alarmVM.isDarkModeOn ?? (colorScheme == .dark)
    }

    private var bedtimeBackgroundColor: Color {
        isDarkModeEnabled ? .black : .white
    }

    private var bedtimeForegroundColor: Color {
        isDarkModeEnabled ? .white : .black
    }

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
                                Image(systemName: "bed.double")
                                    .font(.system(size: iconSize + 44))
                                    .foregroundStyle(.blue)
                                    .opacity(StyleConstants.mainScreenIconOpacity)
                                    .frame(width: 180, height: 180)
                                    .accessibilityHidden(true)

                                VStack(alignment: .center, spacing: 10) {
                                    Text("Good Evening")
                                        .font(.system(size: mainFontSize + 6, weight: .bold))
                                        .accessibilityAddTraits(.isHeader)
                                        .accessibilityFocused($isBedtimeHeaderFocused)
                                    Text("Are you going to bed?")
                                        .font(.system(size: mainFontSize))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }

                            VStack(spacing: 16) {
                                if shouldUseVerticalActionLayout {
                                    VStack(spacing: 12) {
                                        bedtimeYesButton
                                        bedtimeNoButton
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        bedtimeYesButton
                                        bedtimeNoButton
                                    }
                                }
                            }
                            .frame(maxWidth: 320, alignment: .center)

                            Button(isDarkModeEnabled ? "LIGHTS ON!" : "LIGHTS OUT!") {
                                Logger.instance.log(tag: isDarkModeEnabled ? LoggerConstants.loggerActionLightsOn : LoggerConstants.loggerActionLightsOut, message: [String: Any]())
                                alarmVM.isDarkModeOn = !isDarkModeEnabled
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(Color.orange)
                            .accessibilityIdentifier("bedtime.lightsToggle")
                            .accessibilityHint(localizedAppString("Toggles the bedtime screen between light and dark appearance."))
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: 760, alignment: .leading)
                        .padding(.top, 12)
                        .padding(36)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        VStack {
                            Image(systemName: "bed.double")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.blue)
                                .opacity(StyleConstants.mainScreenIconOpacity)
                                .accessibilityHidden(true)
                            Text("Good Evening")
                                .font(.system(size: mainFontSize))
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($isBedtimeHeaderFocused)
                            Text("Are you going to bed?")
                                .font(.system(size: mainFontSize))
                                .multilineTextAlignment(.center)
                            Group {
                                if shouldUseVerticalActionLayout {
                                    VStack(spacing: 12) {
                                        bedtimeYesButton
                                        bedtimeNoButton
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        bedtimeYesButton
                                        bedtimeNoButton
                                    }
                                    .frame(maxWidth: 320, alignment: .center)
                                }
                            }
                            .padding(.bottom)
                            Button(isDarkModeEnabled ? "LIGHTS ON!" : "LIGHTS OUT!") {
                                Logger.instance.log(tag: isDarkModeEnabled ? LoggerConstants.loggerActionLightsOn : LoggerConstants.loggerActionLightsOut, message: [String: Any]())
                                alarmVM.isDarkModeOn = !isDarkModeEnabled
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.orange)
                            .accessibilityIdentifier("bedtime.lightsToggle")
                            .accessibilityHint(localizedAppString("Toggles the bedtime screen between light and dark appearance."))
                        }
                    }
                }
                .padding(edgePadding)
                .frame(minHeight: size.height)
                .foregroundStyle(bedtimeForegroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bedtimeBackgroundColor.ignoresSafeArea())
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
            Text(localizedAppString("This was your last sample. Thank you for participating in the study! Please export your logs and send them to your study contact email."))
        }
        .alert("Remaining samples", isPresented: $showRemainingSamplesAlert) {
            Button("Keep Samples", role: .cancel) { }
            Button("Mark as missed", role: .destructive) {
                continueBedtimeFlow(markRemainingDaytimeSamplesAsMissed: true)
            }
        } message: {
            Text(
                String(
                    format: localizedAppString("%lld daytime samples are still open. Do you want to mark them as missed and finish the study day after bedtime is recorded?"),
                    Int64(alarmVM.remainingDaytimeSampleCountForCurrentDay())
                )
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isBedtimeHeaderFocused = true
            }
        }
        .onChange(of: isScannerPresented) { isPresented in
            guard !isPresented, pendingFinishAfterEveningSample else {
                return
            }

            if alarmVM.isEveningScanned {
                finishDayFromBedtime()
            } else {
                pendingFinishAfterEveningSample = false
                pendingMissedTimedAlarmsSnapshot = nil
            }
        }
        .onChange(of: showStudyFinishedAlert) { isPresented in
            if isPresented {
                postAccessibilityAnnouncement(localizedAppString("Study finished. Please export your logs and send them to your study contact email."))
            }
        }
    }
    private var bedtimeYesButton: some View {
        Button("YES") {
            if alarmVM.remainingDaytimeSampleCountForCurrentDay() > 0 {
                showRemainingSamplesAlert = true
                return
            }

            continueBedtimeFlow(markRemainingDaytimeSamplesAsMissed: false)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("bedtime.yes")
        .accessibilityLabel(localizedAppString("Yes, I am going to bed"))
        .accessibilityHint(localizedAppString("Starts the bedtime flow and may open the scanner for an evening sample."))
    }

    private var bedtimeNoButton: some View {
        Button("NO") {
            if alarmVM.isStudyFinished() {
                showStudyFinishedAlert = true
                return
            }

            toastType = studyDataVM.studyData.hasEveningSample ? .bedtimeReminderToast : .noSampleTonightToast
            showToast = true
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("bedtime.no")
        .accessibilityLabel(localizedAppString("No, I am not going to bed"))
        .accessibilityHint(localizedAppString("Keeps the bedtime flow unchanged and shows a reminder if needed."))
    }

    private func continueBedtimeFlow(markRemainingDaytimeSamplesAsMissed: Bool) {
        pendingMissedTimedAlarmsSnapshot = markRemainingDaytimeSamplesAsMissed ? alarmVM.missedDaytimeSamplesSnapshotForBedtime() : nil

        if studyDataVM.studyData.hasEveningSample {
            if !alarmVM.isEveningScanned {
                pendingFinishAfterEveningSample = markRemainingDaytimeSamplesAsMissed
                alarmId = AlarmConstants.eveningAlarmId
                scannerSource = .schedule
                isScannerPresented = true
            } else if markRemainingDaytimeSamplesAsMissed {
                finishDayFromBedtime()
            } else if alarmVM.isStudyFinished() {
                showStudyFinishedAlert = true
            } else {
                toastType = .eveningSampleTakenToast
                showToast = true
            }
        } else if markRemainingDaytimeSamplesAsMissed {
            finishDayFromBedtime()
        } else {
            toastType = .noEveningSampleToast
            showToast = true
        }
    }

    private func finishDayFromBedtime() {
        let finishedStudyDay = alarmVM.studyDayCounter
        let didFinishDay = alarmVM.finishCurrentStudyDayFromBedtime(missedTimedAlarmsSnapshot: pendingMissedTimedAlarmsSnapshot)
        pendingFinishAfterEveningSample = false
        pendingMissedTimedAlarmsSnapshot = nil

        guard didFinishDay else {
            return
        }

        finishedStudyDayToDisplay = finishedStudyDay
        selectedTab = 1
        if alarmVM.isStudyFinished() {
            showStudyFinishedAlert = true
        } else {
            toastType = .feedbackToast
            showToast = true
        }
    }
}

#Preview {
    BedtimeView(
        isScannerPresented: .constant(false),
        alarmId: .constant(AlarmConstants.eveningAlarmId),
        scannerSource: .constant(nil),
        selectedTab: .constant(2),
        finishedStudyDayToDisplay: .constant(nil)
    )
        .environmentObject(AlarmViewModel())
        .environmentObject(StudyDataViewModel())
}
