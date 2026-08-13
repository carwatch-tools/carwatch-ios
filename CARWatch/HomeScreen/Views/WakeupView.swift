import SwiftUI

private enum PostWakeupAlertType {
    case delayedSample
    case overdueSample
}

struct WakeupView: View {
    private let overdueSampleGracePeriod: TimeInterval = 2 * 60

    @AccessibilityFocusState private var isWakeupHeaderFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel

    @State var showToast: Bool = false
    @State var toastType: NotificationConstants.WakeupToastType = .feedbackToast
    @State private var delayedSampleMinutes: Int = 0
    @State private var showPostWakeupAlert: Bool = false
    @State private var postWakeupAlertType: PostWakeupAlertType = .delayedSample
    @State private var showStudyFinishedAlert: Bool = false
    @State private var showPreviousWakeupTimeSheet: Bool = false
    @State private var previousWakeupTime: Date = Date()
    
    @Binding var initialAlarmTime: Date
    @Binding var isScannerPresented: Bool
    @Binding var scannerSource: ScannerPresentationSource?
    @Binding var pendingWakeupConfirmationTime: Date?
    @Binding var showPreviousDayUnfinishedAlert: Bool
    var onDelayedSampleAcknowledged: () -> Void = {}

    private var shouldUseVerticalActionLayout: Bool {
        StyleConstants.isAccessibilitySize(dynamicTypeSize)
    }

    private var toastMessage: String {
        switch toastType {
        case .feedbackToast:
            return localizedAppString("Thank you for your feedback!")
        case .wakeupReminderToast:
            return localizedAppString("Please remember to take your sample\nwhen you wake up.")
        case .wakeupReportedToast:
            return localizedAppString("You have already reported your wakeup.")
        case .delayedSampleToast:
            return ""
        }
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
                                previousWakeupButton
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
                                previousWakeupButton
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
        .topToast(isPresented: $showToast, message: toastMessage)
        .alert(postWakeupAlertTitle, isPresented: $showPostWakeupAlert) {
            Button("OK", role: .cancel) {
                onDelayedSampleAcknowledged()
            }
        } message: {
            Text(postWakeupAlertMessage)
        }
        .alert(localizedAppString("Continue or start a study day?"), isPresented: $showPreviousDayUnfinishedAlert) {
            Button(localizedAppString("Continue current study day"), role: .cancel) { }
            Button(localizedAppString("Finish and start today")) {
                performWakeupConfirmation()
            }
        } message: {
            Text(previousDayUnfinishedMessage)
        }
        .alert(localizedAppString("Study Finished"), isPresented: $showStudyFinishedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localizedAppString("You have already finished the study.\nThanks for participating!\nPlease export your logs and send them to your study contact email."))
        }
        .sheet(isPresented: $showPreviousWakeupTimeSheet) {
            previousWakeupTimeSheet
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isWakeupHeaderFocused = true
            }
        }
        .onChange(of: showPostWakeupAlert) { isPresented in
            if isPresented {
                postAccessibilityAnnouncement(postWakeupAccessibilityAnnouncement)
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

            let wakeupAlreadyReportedToday = alarmVM.isWakeupConfirmedToday()
            let shouldFinishPreviousDay = alarmVM.shouldFinishPreviousDayOnWakeupConfirmation()

            if wakeupAlreadyReportedToday {
                toastType = .wakeupReportedToast
                showToast = true
            } else {
                var msg = [String: Any]()
                msg[LoggerConstants.loggerExtraAlarmId] = AlarmConstants.initialAlarmId
                Logger.instance.log(tag: LoggerConstants.loggerActionSpontaneousAwakening, message: msg)
                initialAlarmTime = Date()
                if shouldFinishPreviousDay {
                    showPreviousDayUnfinishedAlert = true
                    return
                }

                if alarmVM.isScanRequired() && !shouldFinishPreviousDay {
                    pendingWakeupConfirmationTime = initialAlarmTime
                    scannerSource = .wakeup
                    isScannerPresented = true
                } else {
                    performWakeupConfirmation()
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

    private var previousWakeupButton: some View {
        Button("Record previous wakeup") {
            if alarmVM.isStudyFinished() {
                showStudyFinishedAlert = true
                return
            }

            if alarmVM.isWakeupConfirmedToday() {
                toastType = .wakeupReportedToast
                showToast = true
                return
            }

            previousWakeupTime = Date()
            showPreviousWakeupTimeSheet = true
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("wakeup.previous")
        .accessibilityLabel(localizedAppString("Record previous wakeup"))
        .accessibilityHint(localizedAppString("Enter the time you woke up earlier so the sample schedule can be calculated."))
    }

    private func performWakeupConfirmation() {
        alarmVM.confirmWakeup(at: initialAlarmTime)
        if hasOverdueSample(before: initialAlarmTime) {
            postWakeupAlertType = .overdueSample
            showPostWakeupAlert = true
        } else if alarmVM.isScanRequired() {
            scannerSource = .wakeup
            isScannerPresented = true
        } else if let nextTimedAlarm = alarmVM.getNextUpcomingAlarm() {
            delayedSampleMinutes = Int(
                ceil(nextTimedAlarm.time.timeIntervalSince(initialAlarmTime) / 60)
            )
            postWakeupAlertType = .delayedSample
            showPostWakeupAlert = true
        }
    }

    private var postWakeupAlertTitle: String {
        switch postWakeupAlertType {
        case .delayedSample:
            return localizedAppString("Delayed sample planned")
        case .overdueSample:
            return localizedAppString("Overdue sample pending")
        }
    }

    private var postWakeupAlertMessage: String {
        switch postWakeupAlertType {
        case .delayedSample:
            return String(
                format: localizedAppString("A delayed sample is planned for your study. You will receive a reminder to take that sample in %lld minutes."),
                Int64(delayedSampleMinutes)
            )
        case .overdueSample:
            return localizedAppString("You still have at least one overdue sample from earlier today. Next, you will be taken to the Schedule screen, where you can choose which sample you want to take now.")
        }
    }

    private var postWakeupAccessibilityAnnouncement: String {
        switch postWakeupAlertType {
        case .delayedSample:
            return String(
                format: localizedAppString("A delayed sample is planned. You will receive a reminder in %lld minutes."),
                Int64(delayedSampleMinutes)
            )
        case .overdueSample:
            return localizedAppString("You still have at least one overdue sample from earlier today. You will now be taken to the Schedule screen, where you can choose which sample you want to take now.")
        }
    }

    private var previousDayUnfinishedMessage: String {
        String(
            format: localizedAppString("The study day that started at %@ still has missing samples. Please choose whether you want to continue the current study day or finish it and start a new study day today, %@."),
            formattedStudyDateTime(alarmVM.pendingUnfinishedStudyDayStartTimeForWakeupConfirmation() ?? alarmVM.dateOfLastInitialAlarm),
            formattedStudyDate(Date())
        )
    }

    private func formattedStudyDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedStudyDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func hasOverdueSample(before wakeupTime: Date) -> Bool {
        alarmVM.timedAlarms.contains { alarm in
            guard alarm.isActive, alarm.isTriggered, !alarm.isScanned else {
                return false
            }

            return wakeupTime.timeIntervalSince(alarm.time) > overdueSampleGracePeriod
        }
    }

    private var previousWakeupTimeSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("When did you wake up?")
                    .font(.body)
                    .multilineTextAlignment(.leading)

                DatePicker("Wakeup time", selection: $previousWakeupTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding()
            .navigationTitle("Wakeup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPreviousWakeupTimeSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        recordPreviousWakeup()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func recordPreviousWakeup() {
        initialAlarmTime = resolvedPreviousWakeupTime()
        pendingWakeupConfirmationTime = nil
        showPreviousWakeupTimeSheet = false

        if alarmVM.shouldFinishPreviousDayOnWakeupConfirmation() {
            showPreviousDayUnfinishedAlert = true
            return
        }

        performWakeupConfirmation()
    }

    private func resolvedPreviousWakeupTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: previousWakeupTime)
        var currentDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        currentDayComponents.hour = selectedComponents.hour
        currentDayComponents.minute = selectedComponents.minute
        currentDayComponents.second = 0

        guard let selectedTimeToday = calendar.date(from: currentDayComponents) else {
            return now
        }

        if selectedTimeToday > now {
            return calendar.date(byAdding: .day, value: -1, to: selectedTimeToday) ?? selectedTimeToday
        }

        return selectedTimeToday
    }
}

#Preview {
    let alarmVM = AlarmViewModel()

    return WakeupView(
        initialAlarmTime: .constant(Date()),
        isScannerPresented: .constant(false),
        scannerSource: .constant(nil),
        pendingWakeupConfirmationTime: .constant(nil),
        showPreviousDayUnfinishedAlert: .constant(false),
        onDelayedSampleAcknowledged: {}
    )
    .environmentObject(alarmVM)
    .environmentObject(StudyDataViewModel())
}
