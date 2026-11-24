import SwiftUI
import Combine
import UniformTypeIdentifiers
import ZIPFoundation

struct MuseBedtimeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var alarmVM: AlarmViewModel
    @ObservedObject private var monitor = MuseOvernightMonitor.shared
    @AppStorage("muse.sampleAlertEnabled") private var sampleAlertEnabled = false
    @State private var testResult: LocalizedStringKey?
    @State private var testScheduling = false
    @State private var clockBackupConfirmed = false
    @State private var now = Date()
    @State private var showDiagnosticExporter = false
    @State private var diagnosticDocument: MuseDiagnosticDocument?
    @State private var preparingOvernightExport = false
    @State private var saveOvernightDiagnostics = false
    @State private var diagnosticExportError = false
    private let clock = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    let openSchedule: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Headband") {
                    Text(monitor.status)
                    if let pairedName = monitor.pairedName {
                        LabeledContent("Saved headband", value: pairedName)
                    }
                    if let firmware = monitor.firmware {
                        LabeledContent("Firmware", value: firmware)
                    }
                    if let battery = monitor.battery {
                        LabeledContent("Battery", value: "\(battery)%")
                    }
                    if let lastSignal = monitor.lastSignalAt {
                        if now.timeIntervalSince(lastSignal) >= 5 {
                            Text("Muse signal interrupted").foregroundStyle(.secondary)
                        }
                        LabeledContent("Last EEG received") {
                            Text(lastSignal, format: .dateTime.hour().minute().second())
                        }
                        if !monitor.channelQuality.isEmpty {
                            LabeledContent("Usable EEG channels (filtered)") {
                                Text("\(monitor.usableChannels) of 4")
                            }
                            DisclosureGroup("EEG channel details") {
                                ForEach(Array(monitor.channelQuality.enumerated()), id: \.offset) { index, quality in
                                    LabeledContent(AthenaWakeDetector.electrodeNames[index]) {
                                        Text(qualityLabel(quality))
                                    }
                                }
                            }
                        }
                    }
                    if monitor.estimate == nil && !monitor.awaitingManualWakeup {
                        connectionControls
                    }
                }

                Section("Signal diagnostics") {
                    if monitor.diagnosticsRecording {
                        if monitor.diagnosticsIncludeRawEEG {
                            Label("Recording 50 Hz filter test", systemImage: "record.circle")
                            Button("Mark fit change") { monitor.markDiagnosticFitChange() }
                        } else {
                            Label("Recording signal diagnostics", systemImage: "record.circle")
                        }
                        Button("Stop recording") { monitor.stopDiagnostics() }
                    } else {
                        Button("Record signal diagnostics") { monitor.startDiagnostics() }
                            .disabled(!monitor.isConnected)
                        Button("Record 50 Hz filter test") { monitor.startDiagnostics(recordFilterTest: true) }
                            .disabled(!monitor.isConnected)
                        if let data = monitor.diagnosticsData {
                            Button("Export diagnostic log") {
                                export(
                                    data, type: .json,
                                    filename: monitor.diagnosticsIncludeRawEEG
                                        ? "CARWatch-Muse-50Hz-Wide-Test.json" : "CARWatch-Muse-Diagnostics.json"
                                )
                            }
                        }
                    }
                    if monitor.diagnosticsFailed {
                        Text("Could not create the diagnostic log.")
                            .foregroundStyle(.secondary)
                    }
                    Text("The 50 Hz test includes up to five minutes of raw and filtered EEG in the export.")
                        .foregroundStyle(.secondary)
                }

                Section("Overnight diagnostics") {
                    if monitor.isOvernightDiagnosticsRecording {
                        Label("Recording overnight EEG and motion", systemImage: "record.circle")
                        Button("Finish diagnostic recording") { monitor.stopOvernightDiagnostics() }
                    } else if monitor.canConfigureOvernightDiagnostics {
                        Toggle("Save overnight EEG and motion", isOn: $saveOvernightDiagnostics)
                        Text("Start overnight tracking to record. CARWatch keeps the last two hours on this iPhone.")
                            .foregroundStyle(.secondary)
                    }
                    if monitor.overnightDiagnosticsFailed {
                        Text("CARWatch could not save all overnight data.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(monitor.overnightRecordings) { recording in
                        Button {
                            exportOvernight(recording)
                        } label: {
                            LabeledContent("Export overnight ZIP") {
                                Text(recording.startedAt, format: .dateTime.month().day().hour().minute())
                            }
                        }
                        .disabled(preparingOvernightExport)
                    }
                    if preparingOvernightExport { ProgressView("Preparing overnight export…") }
                }

                Section("Backup wake-up alarm") {
                    if let backup = alarmVM.nextBackupWakeup() {
                        let alarmScheduled = NotificationManager.instance.isWakeupAlarmScheduled(id: backup.id, at: backup.date)
                        LabeledContent("Scheduled wake-up time") {
                            Text(backup.date, format: .dateTime.weekday().hour().minute())
                        }
                        if alarmScheduled {
                            Label("Backup alarm set", systemImage: "alarm.fill")
                        } else {
                            Text("Set an alarm for this time in the iPhone Clock app.")
                            Toggle("I set the Clock backup alarm", isOn: $clockBackupConfirmed)
                        }
                    } else {
                        Text("Set your wake-up time and turn on the wake-up reminder in Schedule.")
                    }
                    Button("Open Schedule", action: openSchedule)
                }

                Section("Overnight tracking") {
                    if let estimate = monitor.estimate {
                        LabeledContent("Estimated wake-up") {
                            Text(estimate.onset, format: .dateTime.hour().minute())
                        }
                        Text("Review the estimate on the Wakeup tab.")
                    } else if monitor.awaitingManualWakeup {
                        Text("Report your wake-up time on the Wakeup tab.")
                    } else if monitor.isTracking {
                        Label("Overnight tracking started", systemImage: "moon.fill")
                        Button("Stop overnight tracking", role: .destructive) {
                            monitor.finish(reason: "stopped_by_participant")
                        }
                    } else {
                        Toggle("Sound an alarm when wake-up is detected", isOn: $sampleAlertEnabled)
                        Button("Start overnight tracking") {
                            guard let backup = alarmVM.nextBackupWakeup(), backupReady else { return }
                            monitor.start(
                                backupAt: backup.date, alertOnDetection: sampleAlertEnabled,
                                saveOvernightDiagnostics: saveOvernightDiagnostics
                            )
                        }
                        .disabled(!canStartTracking)
                        Text("After two hours of tracking, Muse can look for wake-up during the 90 minutes before the backup alarm. Review the estimate before using it for study samples.")
                            .foregroundStyle(.secondary)
                    }
#if DEBUG
                    Button("Test sample alert in 10 seconds", action: testAlert)
                        .disabled(testScheduling)
                    if let testResult { Text(testResult).foregroundStyle(.secondary) }
#endif
                }
            }
            .navigationTitle("Muse EEG")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                monitor.refresh()
                monitor.loadOvernightRecordings()
            }
            .onReceive(clock) { date in
                now = date
                monitor.refresh(at: date)
            }
            .onDisappear {
                monitor.stopDiagnostics()
                monitor.closePreview()
            }
            .fileExporter(
                isPresented: $showDiagnosticExporter,
                document: diagnosticDocument,
                contentType: diagnosticDocument?.contentType ?? .json,
                defaultFilename: diagnosticDocument?.filename
            ) { result in
                diagnosticDocument = nil
                if case .failure = result { diagnosticExportError = true }
            }
            .alert("Could not export the diagnostic log", isPresented: $diagnosticExportError) {
                Button("OK", role: .cancel) { }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { monitor.refresh() }
            }
        }
    }

    private func export(_ data: Data, type: UTType, filename: String) {
        diagnosticDocument = MuseDiagnosticDocument(data: data, contentType: type, filename: filename)
        showDiagnosticExporter = true
    }

    private func exportOvernight(_ recording: MuseOvernightDiagnostics.Recording) {
        preparingOvernightExport = true
        Task { @MainActor in
            defer { preparingOvernightExport = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    let root = try MuseOvernightDiagnostics.storageDirectory()
                    let folder = MuseOvernightDiagnostics.recordingDirectory(recording.id, in: root)
                    let archive = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + ".zip")
                    defer { try? FileManager.default.removeItem(at: archive) }
                    try FileManager.default.zipItem(at: folder, to: archive,
                                                     shouldKeepParent: false, compressionMethod: .deflate)
                    return try Data(contentsOf: archive)
                }.value
                let date = recording.startedAt.formatted(.iso8601.year().month().day().dateSeparator(.dash))
                export(data, type: .zip, filename: "CARWatch-Muse-Overnight-\(date).zip")
            } catch {
                diagnosticExportError = true
            }
        }
    }

    private func qualityLabel(_ quality: AthenaWakeDetector.ChannelQuality) -> LocalizedStringKey {
        switch quality {
        case .usable: "Usable"
        case .flat: "Very little variation"
        case .clipped: "Signal reached sensor limit"
        case .largeSwings: "Large signal swings"
        case .electricalNoise: "Electrical interference"
        }
    }

    private var canStartTracking: Bool {
        guard monitor.isConnected, monitor.usableChannels >= 2, let lastSignal = monitor.lastSignalAt,
              now.timeIntervalSince(lastSignal) < 3 else { return false }
        return backupReady
    }

    private var backupReady: Bool {
        guard let backup = alarmVM.nextBackupWakeup() else { return false }
        return clockBackupConfirmed || NotificationManager.instance.isWakeupAlarmScheduled(id: backup.id, at: backup.date)
    }

    @ViewBuilder
    private var connectionControls: some View {
        if !monitor.isConnected {
            if monitor.pairedName != nil && !monitor.isBusy {
                Button("Reconnect saved headband") { monitor.reconnect() }
            }
            if !monitor.isTracking {
                ForEach(monitor.devices) { device in
                    Button(device.name) { monitor.connect(to: device.id) }
                }
                Button("Find Muse headbands") { monitor.scan() }
            } else if !monitor.isBusy {
                Button("Reconnect saved headband") { monitor.reconnect() }
            }
        } else if !monitor.isTracking {
            Button("Disconnect headband") { monitor.closePreview() }
        }
    }

#if DEBUG
    private func testAlert() {
        testScheduling = true
        Task { @MainActor in
            let id = MuseOvernightMonitor.alertPrefix + "test"
            NotificationManager.instance.cancelMuseAlert(id: id)
            let delivery = await NotificationManager.instance.scheduleMuseAlert(id: id, test: true)
            switch delivery {
            case "alarm_kit": testResult = "Test alarm scheduled. You can lock your iPhone."
            case "notification": testResult = "Test sent as a notification. Check CARWatch alarm access in Settings."
            default: testResult = "Could not schedule a test alert. Check CARWatch permissions in Settings."
            }
            testScheduling = false
        }
    }
#endif
}


private struct MuseDiagnosticDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .zip]
    let data: Data
    let contentType: UTType
    let filename: String

    init(data: Data, contentType: UTType, filename: String) {
        self.data = data
        self.contentType = contentType
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        contentType = configuration.contentType
        filename = configuration.file.preferredFilename ?? "CARWatch-Muse-Diagnostics"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
