import CoreBluetooth
import SwiftUI

final class MuseOvernightMonitor: NSObject, ObservableObject {
    static let shared = MuseOvernightMonitor()

    struct Device: Identifiable {
        let id: UUID
        let name: String
    }

    private struct Night: Codable {
        let id: UUID
        let startedAt: Date
        let backupAt: Date
        let alertOnDetection: Bool
        var estimate: AthenaWakeDetector.Estimate?
        var backupTimeReached: Bool?
        var savesOvernightDiagnostics: Bool?
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var status: LocalizedStringKey = "Muse disconnected"
    @Published private(set) var battery: Int?
    @Published private(set) var channelQuality: [AthenaWakeDetector.ChannelQuality] = []
    var usableChannels: Int { channelQuality.filter { $0 == .usable }.count }
    @Published private(set) var lastSignalAt: Date?
    @Published private(set) var pairedName: String?
    @Published private(set) var firmware: String?
    @Published private var night: Night?
    @Published private(set) var diagnosticsRecording = false
    @Published private(set) var diagnosticsData: Data?
    @Published private(set) var diagnosticsFailed = false
    @Published private(set) var diagnosticsIncludeRawEEG = false
    @Published private(set) var overnightRecordings: [MuseOvernightDiagnostics.Recording] = []
    @Published private(set) var overnightDiagnosticsFailed = false

    var isOvernightDiagnosticsRecording: Bool { overnightCapture != nil }
    var canConfigureOvernightDiagnostics: Bool { night == nil }
    private var keepsOvernightConnection: Bool { isTracking || isOvernightDiagnosticsRecording }

    var isTracking: Bool { night != nil && night?.estimate == nil && night?.backupTimeReached != true }
    var awaitingManualWakeup: Bool { night?.backupTimeReached == true }
    var isConnected: Bool { peripheral?.state == .connected }
    var isBusy: Bool { scanRequested || peripheral != nil }
    var estimate: AthenaWakeDetector.Estimate? { night?.estimate }

    static let alertPrefix = "muse-wakeup-"
    private static let service = CBUUID(string: "FE8D")
    private static let control = CBUUID(string: "273E0001-4C4D-454D-96BE-F03BAC821358")
    private static let eeg = CBUUID(string: "273E0013-4C4D-454D-96BE-F03BAC821358")
    private static let secondary = CBUUID(string: "273E0014-4C4D-454D-96BE-F03BAC821358")

    private let defaults = UserDefaults.standard
    private let nightKey = "muse.overnightSession"
    private let deviceKey = "muse.deviceID"
    private let nameKey = "muse.deviceName"
    private let detector = AthenaWakeDetector()
    private var diagnosticCapture: MuseSignalDiagnostics?
    private var overnightCapture: MuseOvernightDiagnostics?
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var discovered: [UUID: CBPeripheral] = [:]
    private var powerOnAction: (() -> Void)?
    private var scanRequested = false
    private var streamTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var controlBuffer = Data()
    private var lastPublishedAt = Date.distantPast
    private var hadUsableSignal: Bool?
    private var lastQualityLogAt = Date.distantPast
    private var studyConfigured = false

    private override init() {
        super.init()
        pairedName = defaults.string(forKey: nameKey)
        if let data = defaults.data(forKey: nightKey) {
            night = try? JSONDecoder().decode(Night.self, from: data)
        }
    }

    func restoreMonitoring() {
        guard night != nil else { return }
        configureStudyLoggerIfNeeded()
        if let night, night.savesOvernightDiagnostics == true {
            openOvernightDiagnostics(for: night)
        }
        refresh()
        if keepsOvernightConnection {
            reconnect()
        } else if awaitingManualWakeup {
            status = "No Muse wake-up estimate"
        } else if estimate != nil {
            status = "Muse wake-up estimate saved"
        }
    }

    func refresh(at now: Date = Date()) {
        if let diagnosticCapture, !diagnosticCapture.canContinue(at: now) {
            stopDiagnostics(at: now)
        }
        guard var night, now >= night.backupAt else { return }
        let wasCapturing = isOvernightDiagnosticsRecording
        finishOvernightDiagnostics(at: night.backupAt, reason: "backup_time_reached")

        if !Calendar.current.isDate(night.backupAt, inSameDayAs: now) {
            finish(reason: "session_expired")
        } else if isTracking {
            night.savesOvernightDiagnostics = false
            night.backupTimeReached = true
            self.night = night
            save()
            log("MUSE_BACKUP_TIME_REACHED", fields: ["wake_detected": false])
            stopConnection()
            status = "No Muse wake-up estimate"
        } else if wasCapturing {
            stopConnection()
            status = "Muse wake-up estimate saved"
        }
    }

    func loadOvernightRecordings() {
        guard let root = try? MuseOvernightDiagnostics.storageDirectory() else { return }
        overnightRecordings = MuseOvernightDiagnostics.completedRecordings(in: root)
    }

    private func openOvernightDiagnostics(for night: Night) {
        do {
            let root = try MuseOvernightDiagnostics.storageDirectory()
            let recording = MuseOvernightDiagnostics.Recording(
                id: night.id, startedAt: night.startedAt, backupAt: night.backupAt,
                systemVersion: UIDevice.current.systemVersion, firmware: firmware,
                detectorVersion: AthenaWakeDetector.version
            )
            overnightCapture = try MuseOvernightDiagnostics(recording: recording, in: root)
        } catch {
            overnightDiagnosticsFailed = true
        }
    }

    private func finishOvernightDiagnostics(
        at date: Date, reason: String, confirmedWakeup: Date? = nil, usedMuseEstimate: Bool? = nil
    ) {
        guard let overnightCapture else { return }
        self.overnightCapture = nil
        do {
            try overnightCapture.finish(
                at: date, reason: reason, estimate: night?.estimate,
                confirmedWakeup: confirmedWakeup, usedMuseEstimate: usedMuseEstimate
            )
        } catch {
            overnightDiagnosticsFailed = true
        }
        if var night {
            night.savesOvernightDiagnostics = false
            self.night = night
            save()
        }
        loadOvernightRecordings()
    }

    func stopOvernightDiagnostics() {
        finishOvernightDiagnostics(at: Date(), reason: "diagnostics_stopped")
        if !isTracking { stopConnection() }
    }

    private func checkpointOvernightDiagnostics() {
        do {
            try overnightCapture?.checkpoint(at: Date())
        } catch {
            overnightDiagnosticsFailed = true
        }
    }

    func startDiagnostics(recordFilterTest: Bool = false) {
        guard isConnected, diagnosticCapture == nil else { return }
        diagnosticsData = nil
        diagnosticsFailed = false
        diagnosticCapture = MuseSignalDiagnostics(
            startedAt: Date(), firmware: firmware, recordFilterTest: recordFilterTest
        )
        diagnosticsIncludeRawEEG = recordFilterTest
        diagnosticsRecording = true
    }

    func markDiagnosticFitChange() {
        diagnosticCapture?.markFitChange(at: Date())
    }

    func stopDiagnostics(at date: Date = Date()) {
        guard let diagnosticCapture else { return }
        self.diagnosticCapture = nil
        do {
            diagnosticsData = try diagnosticCapture.finish(
                at: date, firmware: firmware, systemVersion: UIDevice.current.systemVersion
            )
        } catch {
            diagnosticsFailed = true
        }
        diagnosticsRecording = false
    }

    func scan() {
        stopConnection()
        devices = []
        discovered = [:]
        scanRequested = true
        status = "Looking for Muse headbands…"
        whenPoweredOn { [weak self] in
            guard let self, self.scanRequested else { return }
            self.central?.scanForPeripherals(withServices: nil)
            self.scanTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled, let self else { return }
                self.scanRequested = false
                self.central?.stopScan()
                self.status = self.devices.isEmpty ? "No Muse headband found" : "Choose your headband"
            }
        }
    }

    func connect(to id: UUID) {
        guard let device = discovered[id] else { return }
        stopConnection()
        connect(device)
    }

    func reconnect() {
        guard let value = defaults.string(forKey: deviceKey), let id = UUID(uuidString: value) else {
            scan()
            return
        }
        guard peripheral == nil else { return }
        status = "Reconnecting to Muse…"
        whenPoweredOn { [weak self] in
            guard let self, self.peripheral == nil else { return }
            if let device = self.central?.retrievePeripherals(withIdentifiers: [id]).first {
                self.connect(device)
            } else if self.keepsOvernightConnection {
                self.status = "Muse connection lost"
            } else {
                self.scan()
            }
        }
    }

    func start(backupAt: Date, alertOnDetection: Bool, saveOvernightDiagnostics: Bool = false) {
        let now = Date()
        guard isConnected, usableChannels >= 2, let lastSignalAt,
              abs(now.timeIntervalSince(lastSignalAt)) < 3, backupAt > now, night == nil else { return }
        configureStudyLoggerIfNeeded()
        detector.reset()
        hadUsableSignal = nil
        lastQualityLogAt = .distantPast
        var night = Night(id: UUID(), startedAt: now, backupAt: backupAt, alertOnDetection: alertOnDetection)
        overnightDiagnosticsFailed = false
        if saveOvernightDiagnostics {
            openOvernightDiagnostics(for: night)
            night.savesOvernightDiagnostics = isOvernightDiagnosticsRecording
        }
        self.night = night
        save()
        log("MUSE_SESSION_STARTED", fields: [
            "alert_enabled": alertOnDetection, "overnight_diagnostics": isOvernightDiagnosticsRecording
        ])
    }

    func completeWakeup(at wakeup: Date, usedEstimate: Bool) {
        guard let night, Calendar.current.isDate(night.backupAt, inSameDayAs: wakeup) else { return }
        log("MUSE_WAKEUP_CONFIRMED", fields: [
            "wakeup_ms": getUnixTimeMillisFromDate(wakeup),
            "source": usedEstimate ? "muse_confirmed" : "participant"
        ])
        if !isOvernightDiagnosticsRecording {
            do {
                let root = try MuseOvernightDiagnostics.storageDirectory()
                try MuseOvernightDiagnostics.addWakeupConfirmation(
                    recordingID: night.id, in: root, at: wakeup, usedMuseEstimate: usedEstimate
                )
                loadOvernightRecordings()
            } catch {
                overnightDiagnosticsFailed = true
            }
        }
        finish(reason: "wakeup_confirmed", confirmedWakeup: wakeup, usedMuseEstimate: usedEstimate)
    }

    func finish(reason: String, confirmedWakeup: Date? = nil, usedMuseEstimate: Bool? = nil) {
        if let night {
            finishOvernightDiagnostics(
                at: min(Date(), night.backupAt), reason: reason,
                confirmedWakeup: confirmedWakeup, usedMuseEstimate: usedMuseEstimate
            )
            log("MUSE_SESSION_ENDED", fields: ["reason": reason, "detected": night.estimate != nil])
            NotificationManager.instance.cancelMuseAlert(id: Self.alertPrefix + night.id.uuidString)
            self.night = nil
            save()
        }
        stopConnection()
        status = "Muse disconnected"
    }

    func closePreview() {
        guard !keepsOvernightConnection else { return }
        stopConnection()
        if awaitingManualWakeup {
            status = "No Muse wake-up estimate"
        } else {
            status = estimate == nil ? "Muse disconnected" : "Muse wake-up estimate saved"
        }
    }

    func resetForStudy() {
        finish(reason: "study_reset")
        diagnosticCapture = nil
        diagnosticsData = nil
        diagnosticsFailed = false
        diagnosticsRecording = false
        diagnosticsIncludeRawEEG = false
        defaults.removeObject(forKey: deviceKey)
        defaults.removeObject(forKey: nameKey)
        pairedName = nil
        studyConfigured = false
    }

    private func whenPoweredOn(_ action: @escaping () -> Void) {
        powerOnAction = action
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil, options: [
                CBCentralManagerOptionRestoreIdentifierKey: "CARWatch.MuseAthena"
            ])
        } else if let central {
            centralManagerDidUpdateState(central)
        }
    }

    private func connect(_ device: CBPeripheral) {
        scanTask?.cancel()
        scanRequested = false
        central?.stopScan()
        peripheral = device
        device.delegate = self
        status = "Connecting to Muse…"
        if device.state == .connected {
            device.discoverServices([Self.service])
        } else {
            central?.connect(device)
        }
        if !keepsOvernightConnection {
            connectTask?.cancel()
            connectTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let self, self.lastSignalAt == nil else { return }
                self.fail("No Athena EEG received. Close the Muse app and try again.")
            }
        }
    }

    private func stopConnection() {
        streamTask?.cancel()
        streamTask = nil
        scanTask?.cancel()
        connectTask?.cancel()
        scanRequested = false
        powerOnAction = nil
        central?.stopScan()
        if let peripheral {
            peripheral.delegate = nil
            central?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        clearSignal()
        battery = nil
        firmware = nil
        controlBuffer.removeAll()
    }

    private func clearSignal() {
        detector.reset()
        channelQuality = []
        lastSignalAt = nil
        lastPublishedAt = .distantPast
    }

    private func fail(_ message: LocalizedStringKey) {
        if isTracking { log("MUSE_CONNECTION_FAILED") }
        stopConnection()
        status = message
    }

    private func beginStreaming(_ device: CBPeripheral, control: CBCharacteristic) {
        streamTask?.cancel()
        streamTask = Task { @MainActor [weak self, weak device] in
            let commands = ["v6", "s", "h", "p1041", "s", "dc001", "dc001", "L1", "s"]
            for token in commands {
                guard !Task.isCancelled, let device, device.state == .connected else { return }
                let payload = Array((token + "\n").utf8)
                let writeType: CBCharacteristicWriteType = control.properties.contains(.writeWithoutResponse)
                    ? .withoutResponse : .withResponse
                device.writeValue(Data([UInt8(payload.count)] + payload), for: control, type: writeType)
                try? await Task.sleep(for: .milliseconds(200))
            }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, let self, self.lastSignalAt == nil,
                  let device, device.state == .connected else { return }
            // Some Athena firmware revisions use the legacy start token.
            device.writeValue(Data([2, 0x64, 0x0a]), for: control, type:
                control.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        }
    }

    private func receiveSignals(_ data: Data, at date: Date) {
        refresh(at: date)
        guard let peripheral else { return }
        let detectionFrom = isTracking ? night.map {
            max(
                $0.backupAt.addingTimeInterval(-AthenaWakeDetector.wakeWindow),
                $0.startedAt.addingTimeInterval(AthenaWakeDetector.minimumSession),
                Calendar.current.startOfDay(for: $0.backupAt)
            )
        } : nil
        let capture = diagnosticCapture
        capture?.receiveNotification(at: date)
        let onWindow = capture.map { capture in capture.append }
        var overnightFrame = overnightCapture.map { _ in MuseOvernightDiagnostics.Frame() }
        var eegSamples = 0
        var result: AthenaWakeDetector.Estimate?
        AthenaPacket.decode(data) { a, b, c, d in
            overnightFrame?.addEEG(a, b, c, d)
            capture?.appendFilterTestSample(a, b, c, d, at: date, startsNotification: eegSamples == 0)
            eegSamples += 1
            if let estimate = self.detector.addEEG(a, b, c, d, at: date, detectionFrom: detectionFrom, diagnostics: onWindow) {
                result = estimate
            }
        } motion: { value in
            overnightFrame?.addMotion(value)
            self.detector.addMotion(value, at: date)
        } battery: { percent in
            if self.battery != percent { self.battery = percent }
        }
        capture?.receiveEEG(samples: eegSamples, at: date)
        if let overnightFrame {
            do {
                try overnightCapture?.append(overnightFrame, at: date)
            } catch {
                overnightDiagnosticsFailed = true
                finishOvernightDiagnostics(at: date, reason: "storage_error")
            }
        }

        if eegSamples > 0, date.timeIntervalSince(lastPublishedAt) >= 1 {
            if let lastSignalAt, date.timeIntervalSince(lastSignalAt) > 3, isTracking {
                log("MUSE_STREAM_GAP", fields: ["seconds": date.timeIntervalSince(lastSignalAt)])
            }
            lastPublishedAt = date
            lastSignalAt = date
            channelQuality = detector.channelQuality
            status = estimate == nil ? "Receiving Muse EEG" : "Muse wake-up estimate saved"
            if defaults.string(forKey: deviceKey) != peripheral.identifier.uuidString {
                let name = peripheral.name ?? "Muse S Athena"
                defaults.set(peripheral.identifier.uuidString, forKey: deviceKey)
                defaults.set(name, forKey: nameKey)
                pairedName = name
            }
            if isTracking, hadUsableSignal != (usableChannels >= 2), date.timeIntervalSince(lastQualityLogAt) >= 10 {
                lastQualityLogAt = date
                hadUsableSignal = usableChannels >= 2
                log("MUSE_SIGNAL_QUALITY", fields: [
                    "usable_channels": usableChannels,
                    "channel_quality": channelQuality.map(\.rawValue)
                ])
            }
        }
        if let result { record(result) }
    }

    private func receiveControl(_ data: Data) {
        guard !data.isEmpty else { return }
        controlBuffer.append(contentsOf: data.dropFirst())
        if controlBuffer.count > 4096 { controlBuffer.removeAll() }
        guard let lineEnd = controlBuffer.lastIndex(of: 0x0a) else { return }
        let lines = controlBuffer.prefix(through: lineEnd).split(separator: 0x0a)
        controlBuffer = Data(controlBuffer.dropFirst(lineEnd + 1))
        for line in lines {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            if let version = object["fw"] as? String, firmware != version { firmware = version }
        }
    }

    private func record(_ estimate: AthenaWakeDetector.Estimate) {
        guard var night, night.estimate == nil else { return }
        night.estimate = estimate
        self.night = night
        save()
        log("MUSE_WAKEUP_ESTIMATED", fields: [
            "estimated_wakeup_ms": getUnixTimeMillisFromDate(estimate.onset),
            "detected_ms": getUnixTimeMillisFromDate(estimate.detectedAt),
            "usable_channels": detector.channelQuality.filter { $0 == .usable }.count
        ])
        if isOvernightDiagnosticsRecording {
            checkpointOvernightDiagnostics()
        } else {
            stopConnection()
        }
        status = "Muse wake-up estimate saved"
        guard night.alertOnDetection else { return }
        let identifier = Self.alertPrefix + night.id.uuidString
        Task { @MainActor in
            let delivery = await NotificationManager.instance.scheduleMuseAlert(id: identifier)
            guard self.night?.id == night.id else {
                NotificationManager.instance.cancelMuseAlert(id: identifier)
                return
            }
            self.log("MUSE_SAMPLE_ALERT_REQUESTED", fields: ["delivery": delivery])
        }
    }

    private func save() {
        defaults.set(night.flatMap { try? JSONEncoder().encode($0) }, forKey: nightKey)
    }

    private func configureStudyLoggerIfNeeded() {
        guard !studyConfigured else { return }
        studyConfigured = true
        let study = StudyDataViewModel().studyData
        Logger.instance.setStudyData(studyName: study.studyName, participantId: study.participantId)
    }

    private func log(_ tag: String, fields: [String: Any] = [:]) {
        guard let night else { return }
        var message = fields
        message["session_id"] = night.id.uuidString
        message["backup_ms"] = getUnixTimeMillisFromDate(night.backupAt)
        message["detector"] = AthenaWakeDetector.version
        Logger.instance.log(tag: tag, message: message)
    }
}

extension MuseOvernightMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            let action = powerOnAction
            powerOnAction = nil
            action?()
        case .poweredOff:
            checkpointOvernightDiagnostics()
            if isTracking, peripheral != nil { log("MUSE_BLUETOOTH_OFF") }
            clearSignal()
            status = "Turn on Bluetooth to use Muse"
        case .unauthorized:
            fail("Allow Bluetooth for CARWatch in Settings")
        case .unsupported:
            fail("Bluetooth is unavailable on this device")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState state: [String: Any]) {
        guard let restored = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        for device in restored {
            guard keepsOvernightConnection, device.identifier.uuidString == defaults.string(forKey: deviceKey) else {
                central.cancelPeripheralConnection(device)
                continue
            }
            peripheral = device
            device.delegate = self
            status = "Restoring Muse connection…"
            powerOnAction = { [weak self, weak device] in
                guard let self, let device, self.peripheral == device else { return }
                if device.state == .connected {
                    device.discoverServices([Self.service])
                } else if device.state == .disconnected {
                    self.central?.connect(device)
                }
            }
            if central.state == .poweredOn { centralManagerDidUpdateState(central) }
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover device: CBPeripheral,
        advertisementData: [String: Any], rssi: NSNumber
    ) {
        guard scanRequested,
              let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? device.name,
              name.lowercased().contains("muse"), discovered[device.identifier] == nil else { return }
        discovered[device.identifier] = device
        devices.append(Device(id: device.identifier, name: name))
    }

    func centralManager(_ central: CBCentralManager, didConnect device: CBPeripheral) {
        guard device == peripheral else { return }
        status = "Checking Athena sensors…"
        device.discoverServices([Self.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect device: CBPeripheral, error: Error?) {
        guard device == peripheral else { return }
        fail("Could not connect to Muse. Try reconnecting.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral device: CBPeripheral, error: Error?) {
        guard device == peripheral else { return }
        streamTask?.cancel()
        streamTask = nil
        clearSignal()
        controlBuffer.removeAll()
        checkpointOvernightDiagnostics()
        refresh()
        if keepsOvernightConnection {
            log("MUSE_DISCONNECTED")
            status = "Muse disconnected. Reconnecting…"
            if central.state == .poweredOn {
                central.connect(device)
            } else {
                peripheral = nil
                reconnect()
            }
        } else {
            peripheral = nil
            status = "Muse disconnected"
        }
    }
}

extension MuseOvernightMonitor: CBPeripheralDelegate {
    func peripheral(_ device: CBPeripheral, didDiscoverServices error: Error?) {
        guard device == peripheral else { return }
        guard let service = device.services?.first(where: { $0.uuid == Self.service }), error == nil else {
            fail("Muse service unavailable")
            return
        }
        device.discoverCharacteristics([Self.control, Self.eeg, Self.secondary], for: service)
    }

    func peripheral(_ device: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard device == peripheral else { return }
        guard let characteristics = service.characteristics, error == nil,
              characteristics.contains(where: { $0.uuid == Self.eeg }),
              characteristics.contains(where: { $0.uuid == Self.control }) else {
            fail("This headband does not expose Athena EEG")
            return
        }
        for characteristic in characteristics where !characteristic.isNotifying {
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                device.setNotifyValue(true, for: characteristic)
            }
        }
        startWhenSubscribed(device, characteristics: characteristics)
    }

    func peripheral(_ device: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard device == peripheral else { return }
        if error != nil, characteristic.uuid != Self.secondary {
            fail("Muse sensor subscription failed")
            return
        }
        startWhenSubscribed(device, characteristics: characteristic.service?.characteristics ?? [])
    }

    private func startWhenSubscribed(_ device: CBPeripheral, characteristics: [CBCharacteristic]) {
        guard streamTask == nil, let control = characteristics.first(where: { $0.uuid == Self.control }),
              control.isNotifying, characteristics.contains(where: { $0.uuid == Self.eeg && $0.isNotifying }) else { return }
        beginStreaming(device, control: control)
    }

    func peripheral(_ device: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard device == peripheral, error == nil, let data = characteristic.value else { return }
        switch characteristic.uuid {
        case Self.eeg, Self.secondary: receiveSignals(data, at: Date())
        case Self.control: receiveControl(data)
        default: break
        }
    }
}
