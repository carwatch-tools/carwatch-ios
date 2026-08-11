import SwiftUI
import AlertToast

enum ActiveAlert {
    case toggleActivityAlert, takeSampleEarlyAlert, recordWakeupBeforeSampleAlert
}

private enum SchedulePostWakeupAlertType {
    case delayedSample
    case overdueSample
}

struct AlarmView: View {
    private let overdueSampleGracePeriod: TimeInterval = 2 * 60

    @AccessibilityFocusState private var isScheduleHeaderFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var alarmVM: AlarmViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @Binding var initialAlarmTime: Date
    @Binding var isScannerPresented: Bool
    @Binding var currentAlarmId: Int?
    @Binding var scannerSource: ScannerPresentationSource?
    @Binding var pendingWakeupConfirmationTime: Date?
    
    @State private var showToast: Bool = false
    @State private var showAlert: Bool = false
    @State private var showDisabledInfoAlert: Bool = false
    @State private var activeAlert: ActiveAlert = .toggleActivityAlert
    @State private var pendingToggleValue: Bool = false
    @State private var pendingToggleIndex: Int = 0
    @State private var eveningReminderSelection = Date()
    @State private var showWakeupTimeChoiceDialog: Bool = false
    @State private var showPreviousWakeupTimeSheet: Bool = false
    @State private var previousWakeupTime: Date = Date()
    @State private var showPostWakeupAlert: Bool = false
    @State private var delayedSampleMinutes: Int = 0
    @State private var postWakeupAlertType: SchedulePostWakeupAlertType = .delayedSample

    private var isWakeupTimeSelectionDisabled: Bool {
        alarmVM.isStudyFinished()
    }

    private var disabledWakeupMessage: LocalizedStringKey {
        alarmVM.isStudyFinished()
            ? "The study is already finished, so the wakeup time can no longer be changed."
            : "The wakeup time can be changed after reporting wakeup."
    }

    private var disabledWakeupAnnouncement: String {
        alarmVM.isStudyFinished()
            ? localizedAppString("The study is already finished, so the wakeup time can no longer be changed.")
            : localizedAppString("The wakeup time can be changed after reporting wakeup.")
    }

    private var shouldUseVerticalWakeupControls: Bool {
        StyleConstants.isAccessibilitySize(dynamicTypeSize)
    }

    private var currentStudyDayText: String {
        guard alarmVM.studyDayCounter > 0 else {
            return localizedAppString("Study day not started")
        }

        if alarmVM.numStudyDays > 0 {
            return String(
                format: localizedAppString("Study day %lld of %lld"),
                Int64(alarmVM.studyDayCounter),
                Int64(alarmVM.numStudyDays)
            )
        }

        return String(
            format: localizedAppString("Study day %lld"),
            Int64(alarmVM.studyDayCounter)
        )
    }

    private func usesExpandedPadLayout(for size: CGSize) -> Bool {
        StyleConstants.isExpandedPadLayout(for: size)
    }

    private func reminderAccessibilityLabel(for alarm: Alarm) -> String {
        String(
            format: localizedAppString("Reminder for sample %@ at %@"),
            "S\(alarm.getSalivaId(startSample: studyDataVM.studyData.startSample))",
            getHourMinFormattedString(time: alarm.time)
        )
    }

    private func sampleActionAccessibilityLabel(for alarm: Alarm) -> String {
        String(
            format: localizedAppString("Take sample %@ at %@"),
            "S\(alarm.getSalivaId(startSample: studyDataVM.studyData.startSample))",
            getHourMinFormattedString(time: alarm.time)
        )
    }

    private func isAlarmMarkedMissed(_ alarm: Alarm) -> Bool {
        guard alarm.isTriggered, !alarm.isScanned else {
            return false
        }

        return true
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let isCompact = StyleConstants.isCompactScreen(for: size)
            let mainFontSize = StyleConstants.mainScreenFontSize(for: size)
            let iconSize = StyleConstants.mainScreenIconSize(for: size)
            let explanationFontSize = StyleConstants.explanationFontSize(for: size)
            let edgePadding = StyleConstants.edgePadding(for: size)
            let onboardingPadding = StyleConstants.onboardingPadding(for: size)
            let usesExpandedLayout = usesExpandedPadLayout(for: size)

            VStack {
                Image(systemName: "alarm")
                    .font(.system(size: usesExpandedLayout ? iconSize + 40 : iconSize))
                    .foregroundStyle(.blue)
                    .opacity(StyleConstants.mainScreenIconOpacity)
                    .padding(.bottom, usesExpandedLayout ? 12 : 0)
                    .accessibilityHidden(true)
                Text("Please set your desired wakeup time for tomorrow.")
                    .font(.system(size: mainFontSize))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isScheduleHeaderFocused)
                    .padding(.bottom, usesExpandedLayout ? 18 : 0)
                Group {
                    if shouldUseVerticalWakeupControls {
                        VStack(spacing: 12) {
                            wakeupControls(isCompact: isCompact, edgePadding: edgePadding, mainFontSize: mainFontSize)
                        }
                    } else {
                        HStack(spacing: usesExpandedLayout ? 20 : 8) {
                            wakeupControls(isCompact: isCompact, edgePadding: edgePadding, mainFontSize: mainFontSize)
                        }
                    }
                }
                .padding(.bottom, usesExpandedLayout ? 18 : 0)
                
                Divider()
                    .padding(.top, usesExpandedLayout ? 18 : 0)
                    .padding(.bottom, usesExpandedLayout ? 36 : 12)
                ScrollView(showsIndicators: false, content: {
                    VStack(alignment: .center, spacing: usesExpandedLayout ? 16 : 8) {
                        Text(currentStudyDayText)
                            .font(.system(size: usesExpandedLayout ? explanationFontSize + 4 : explanationFontSize + 2, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier("schedule.currentStudyDay")

                        Text("Saliva sample reminders")
                            .font(.system(size: usesExpandedLayout ? explanationFontSize + 2 : explanationFontSize))
                            .frame(maxWidth: .infinity, alignment: .center)
                        ForEach(Array(alarmVM.timedAlarms.enumerated()), id: \.1) {
                            index, alarm in
                            HStack(alignment: .center, spacing: usesExpandedLayout ? 16 : (isCompact ? 8 : 10)) {
                                HStack(alignment: .center, spacing: 6) {
                                    Text("S\(alarm.getSalivaId(startSample: studyDataVM.studyData.startSample)):")
                                        .font(.system(size: explanationFontSize))
                                        .frame(width: isCompact ? 34 : 40, alignment: .leading)
                                        .accessibilityHidden(true)

                                    Toggle("", isOn: timedAlarmActivityBinding(index: index))
                                        .labelsHidden()
                                        .disabled(alarm.isScanned)
                                        .frame(width: isCompact ? 40 : 50)
                                        .accessibilityIdentifier("schedule.toggle.\(alarm.id)")
                                        .accessibilityLabel(reminderAccessibilityLabel(for: alarm))
                                        .accessibilityValue(alarmVM.timedAlarmActivity.indices.contains(index) && alarmVM.timedAlarmActivity[index] ? localizedAppString("On") : localizedAppString("Off"))
                                        .accessibilityHint(localizedAppString("Turns this sample reminder on or off."))

                                    Color.clear
                                        .frame(width: isCompact ? 4 : 6)
                                        .accessibilityHidden(true)

                                    Text(getHourMinFormattedString(time: alarm.time))
                                        .font(.system(size: explanationFontSize))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .frame(width: isCompact ? 74 : 92, alignment: .leading)
                                        .accessibilityHidden(true)
                                }
                                sampleTrailingColumn(for: alarm, fontSize: explanationFontSize)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, usesExpandedLayout ? 4 : 0)
                            .accessibilityElement(children: .contain)
                        }

                        if studyDataVM.studyData.hasEveningSample {
                            VStack(spacing: 6) {
                                Text("Evening sample reminder")
                                    .font(.system(size: usesExpandedLayout ? explanationFontSize + 2 : explanationFontSize))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                eveningReminderControls(isCompact: isCompact, edgePadding: edgePadding)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, usesExpandedLayout ? 20 : 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, usesExpandedLayout ? onboardingPadding + 8 : onboardingPadding)
                })
                .frame(maxWidth: .infinity)
                .toast(isPresenting: $showToast, duration: StyleConstants.toastDuration) {
                    let color = Color(UIColor.secondarySystemBackground)
                    let toastMsg = localizedAppString("Wakeup alarm set for tomorrow.\nAdjust the time if needed.")
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
                    case .recordWakeupBeforeSampleAlert:
                        return Alert(
                            title: Text("Record wakeup first"),
                            message: Text("Please record when you woke up before scanning a sample."),
                            dismissButton: .default(Text("OK")) {
                                currentAlarmId = nil
                                showAlert = false
                            }
                        )
                    case .toggleActivityAlert:
                        return Alert(title: Text("This only disables the reminder. The sample still needs to be taken and recorded. Are you sure you want to turn off this reminder?"),
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
                .alert(localizedAppString("Wakeup time unavailable"), isPresented: $showDisabledInfoAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(disabledWakeupMessage)
                }
                .alert(schedulePostWakeupAlertTitle, isPresented: $showPostWakeupAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(schedulePostWakeupAlertMessage)
                }
                .confirmationDialog(
                    localizedAppString("Record wakeup first"),
                    isPresented: $showWakeupTimeChoiceDialog,
                    titleVisibility: .visible
                ) {
                    Button("Previously") {
                        previousWakeupTime = Date()
                        showPreviousWakeupTimeSheet = true
                    }
                    Button("Now") {
                        recordWakeupNowFromSchedule()
                    }
                    Button("Cancel", role: .cancel) {
                        currentAlarmId = nil
                    }
                } message: {
                    Text("Please record when you woke up before scanning a sample. This lets CARWatch calculate today's sample schedule.")
                }
                .sheet(isPresented: $showPreviousWakeupTimeSheet) {
                    previousWakeupTimeSheet
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isScheduleHeaderFocused = true
                    }
                    initialAlarmTime = alarmVM.wakeupAlarmSelectionTime()
                    eveningReminderSelection = alarmVM.eveningReminderTime ?? defaultEveningReminderSelection()
                    if alarmVM.shouldPromptForEveningReminderSetup && studyDataVM.studyData.hasEveningSample {
                        alarmVM.shouldPromptForEveningReminderSetup = false
                    }
                }
                .onChange(of: showAlert) { isPresented in
                    guard isPresented else {
                        return
                    }

                    switch activeAlert {
                    case .takeSampleEarlyAlert:
                        postAccessibilityAnnouncement(localizedAppString("This sample is scheduled for later. Are you sure you want to scan the sample now?"))
                    case .recordWakeupBeforeSampleAlert:
                        postAccessibilityAnnouncement(localizedAppString("Please record when you woke up before scanning a sample."))
                    case .toggleActivityAlert:
                        postAccessibilityAnnouncement(localizedAppString("This only disables the reminder. The sample still needs to be taken and recorded. Are you sure you want to turn off this reminder?"))
                    }
                }
                .onChange(of: showDisabledInfoAlert) { isPresented in
                    if isPresented {
                        postAccessibilityAnnouncement(disabledWakeupAnnouncement)
                    }
                }
                .onChange(of: alarmVM.shouldPromptForEveningReminderSetup) { shouldPrompt in
                    if shouldPrompt && studyDataVM.studyData.hasEveningSample {
                        eveningReminderSelection = alarmVM.eveningReminderTime ?? defaultEveningReminderSelection()
                        alarmVM.shouldPromptForEveningReminderSetup = false
                    }
                }
                Spacer()
            }
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
    private func sampleTrailingContent(for alarm: Alarm, fontSize: CGFloat) -> some View {
        if alarm.isScanned {
            Image(systemName: "checkmark.circle")
                .font(.system(size: fontSize))
                .foregroundStyle(.green)
                .accessibilityLabel(
                    String(
                        format: localizedAppString("Sample %@ already recorded"),
                        "S\(alarm.getSalivaId(startSample: studyDataVM.studyData.startSample))"
                    )
                )
        } else {
            sampleActionButton(for: alarm, fontSize: fontSize, isMissed: alarm.isTriggered && isAlarmMarkedMissed(alarm))
        }
    }

    private func sampleActionButton(for alarm: Alarm, fontSize: CGFloat, isMissed: Bool) -> some View {
        Button(action: {
            currentAlarmId = alarm.id
            if !alarmVM.isWakeupConfirmedToday() {
                previousWakeupTime = Date()
                showWakeupTimeChoiceDialog = true
            } else if !alarm.isTriggered {
                // alarm has not been triggered yet, which means the dedicated sampling time was not yet reached
                activeAlert = .takeSampleEarlyAlert
                showAlert = true
            } else {
                scannerSource = .schedule
                isScannerPresented = true
            }
        }) {
            HStack(spacing: 6) {
                if isMissed {
                    Image(systemName: "exclamationmark.arrow.circlepath")
                        .foregroundStyle(.orange)
                        .frame(width: 16, alignment: .center)
                } else {
                    Image(systemName: "barcode.viewfinder")
                        .frame(width: 16, alignment: .center)
                }

                Text("Take sample")
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isMissed ? .orange : .primary)
            }
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("schedule.takeSample.\(alarm.id)")
        .accessibilityLabel(sampleActionAccessibilityLabel(for: alarm))
        .accessibilityHint(localizedAppString(isMissed ? "Opens the barcode scanner for this late sample." : "Opens the barcode scanner for this sample."))
    }

    private func sampleTrailingReference(fontSize: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)
            Text("Take sample")
                .font(.system(size: fontSize))
                .lineLimit(1)
        }
    }

    private func sampleTrailingColumn(for alarm: Alarm, fontSize: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            sampleTrailingReference(fontSize: fontSize)
                .hidden()
            sampleTrailingContent(for: alarm, fontSize: fontSize)
        }
    }

    @ViewBuilder
    private func wakeupControls(isCompact: Bool, edgePadding: CGFloat, mainFontSize: CGFloat) -> some View {
        HStack {
            Toggle("", isOn: Binding<Bool>(
                get: { alarmVM.getInitialAlarm().isActive },
                set: { newValue in
                    setInitialAlarmActivity(isActive: newValue)
                }))
            .labelsHidden()
            .padding(edgePadding)
            .font(.system(size: mainFontSize))
            .accessibilityIdentifier("schedule.initialToggle")
            .accessibilityLabel(localizedAppString("Wakeup reminder"))
            .accessibilityValue(alarmVM.getInitialAlarm().isActive ? localizedAppString("On") : localizedAppString("Off"))
            .accessibilityHint(localizedAppString("Turns tomorrow's wakeup reminder on or off."))

            DatePicker("", selection: $initialAlarmTime, displayedComponents: .hourAndMinute)
                .onChange(of: initialAlarmTime, perform: { _ in
                    let backupTime = alarmVM.getInitialAlarm().time
                    alarmVM.updateWakeupAlarmSelection(time: initialAlarmTime)
                    if !Calendar.current.isDate(alarmVM.dateOfLastInitialAlarm, inSameDayAs: Date()),
                       let firstTimedAlarm = alarmVM.timedAlarms.first,
                       initialAlarmTime > firstTimedAlarm.time {
                        initialAlarmTime = backupTime
                        alarmVM.updateWakeupAlarmSelection(time: initialAlarmTime)
                    }
                    if alarmVM.getInitialAlarm().isActive {
                        showToast = true
                    }
                })
                .labelsHidden()
                .scaleEffect(isCompact ? CGSize(width: 1.15, height: 1.15) : CGSize(width: 1.35, height: 1.35))
                .accessibilityIdentifier("schedule.initialTime")
                .accessibilityLabel(localizedAppString("Wakeup time"))
                .accessibilityHint(localizedAppString("Select your desired wakeup time for tomorrow."))
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
            .accessibilityIdentifier("schedule.disabledInfo")
            .accessibilityLabel("Why is wakeup time disabled?")
        }
    }

    private func eveningReminderControls(isCompact: Bool, edgePadding: CGFloat) -> some View {
        HStack(spacing: 14) {
            Toggle("", isOn: Binding<Bool>(
                get: { alarmVM.eveningReminderTime != nil },
                set: { isEnabled in
                    if isEnabled {
                        alarmVM.scheduleEveningReminder(
                            time: eveningReminderSelection,
                            eveningSampleId: studyDataVM.studyData.eveningSampleId
                        )
                    } else {
                        alarmVM.cancelEveningReminder()
                    }
                }
            ))
            .labelsHidden()
            .accessibilityIdentifier("schedule.eveningReminderToggle")
            .accessibilityLabel(localizedAppString("Evening sample reminder"))
            .accessibilityValue(alarmVM.eveningReminderTime == nil ? localizedAppString("Off") : localizedAppString("On"))
            .accessibilityHint(localizedAppString("Turns the evening sample reminder on or off."))

            DatePicker("", selection: $eveningReminderSelection, displayedComponents: .hourAndMinute)
                .onChange(of: eveningReminderSelection) { newValue in
                    guard alarmVM.eveningReminderTime != nil else {
                        return
                    }

                    alarmVM.scheduleEveningReminder(
                        time: newValue,
                        eveningSampleId: studyDataVM.studyData.eveningSampleId
                    )
                }
                .labelsHidden()
                .scaleEffect(isCompact ? CGSize(width: 1.15, height: 1.15) : CGSize(width: 1.35, height: 1.35))
                .accessibilityIdentifier("schedule.eveningReminderTime")
                .accessibilityLabel(localizedAppString("Evening reminder time"))
                .accessibilityHint(localizedAppString("Select when you want to be reminded to take your evening sample."))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func defaultEveningReminderSelection() -> Date {
        if let lastEveningReminderSelection = alarmVM.lastEveningReminderSelection {
            return lastEveningReminderSelection
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 21
        components.minute = 0

        return Calendar.current.date(from: components) ?? Date()
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
                        currentAlarmId = nil
                        showPreviousWakeupTimeSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        recordPreviousWakeupFromSchedule()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func recordPreviousWakeupFromSchedule() {
        let wakeupTime = resolvedPreviousWakeupTime()
        pendingWakeupConfirmationTime = nil
        currentAlarmId = nil
        scannerSource = nil
        showPreviousWakeupTimeSheet = false
        alarmVM.confirmWakeup(at: wakeupTime)
        initialAlarmTime = alarmVM.wakeupAlarmSelectionTime()
    }

    private func recordWakeupNowFromSchedule() {
        let wakeupTime = Date()
        pendingWakeupConfirmationTime = nil
        alarmVM.confirmWakeup(at: wakeupTime)
        initialAlarmTime = alarmVM.wakeupAlarmSelectionTime()

        guard let firstTimedAlarm = alarmVM.timedAlarms.first,
              firstTimedAlarm.isActive,
              firstTimedAlarm.isTriggered,
              !firstTimedAlarm.isScanned,
              abs(firstTimedAlarm.time.timeIntervalSince(wakeupTime)) < 60 else {
            currentAlarmId = nil
            scannerSource = nil
            showSchedulePostWakeupMessage(wakeupTime: wakeupTime)
            return
        }

        currentAlarmId = firstTimedAlarm.id
        scannerSource = .wakeup
        isScannerPresented = true
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

    private func showSchedulePostWakeupMessage(wakeupTime: Date) {
        if hasOverdueSample(before: wakeupTime) {
            postWakeupAlertType = .overdueSample
            showPostWakeupAlert = true
        } else if let nextTimedAlarm = alarmVM.getNextUpcomingAlarm() {
            delayedSampleMinutes = max(0, Int(ceil(nextTimedAlarm.time.timeIntervalSince(wakeupTime) / 60)))
            postWakeupAlertType = .delayedSample
            showPostWakeupAlert = true
        }
    }

    private var schedulePostWakeupAlertTitle: String {
        switch postWakeupAlertType {
        case .delayedSample:
            return localizedAppString("Delayed sample planned")
        case .overdueSample:
            return localizedAppString("Overdue sample pending")
        }
    }

    private var schedulePostWakeupAlertMessage: String {
        switch postWakeupAlertType {
        case .delayedSample:
            return String(
                format: localizedAppString("A delayed sample is planned for your study. You will receive a reminder to take that sample in %lld minutes."),
                Int64(delayedSampleMinutes)
            )
        case .overdueSample:
            return localizedAppString("You still have at least one overdue sample from earlier today. Please choose which sample you want to take now from the Schedule screen.")
        }
    }

    private func hasOverdueSample(before wakeupTime: Date) -> Bool {
        alarmVM.timedAlarms.contains { alarm in
            guard alarm.isActive, alarm.isTriggered, !alarm.isScanned else {
                return false
            }

            return wakeupTime.timeIntervalSince(alarm.time) > overdueSampleGracePeriod
        }
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
            scannerSource: .constant(nil),
            pendingWakeupConfirmationTime: .constant(nil)
        )
        .environmentObject(alarmVM)
        .environmentObject(StudyDataViewModel())
    }
}

#Preview {
    AlarmView_PreviewContainer()
        .environment(\.locale, currentAppLocale())
}
