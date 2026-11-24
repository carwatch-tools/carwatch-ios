import Foundation

final class MuseOvernightDiagnostics {
    static let retention: TimeInterval = 2 * 60 * 60
    private static let chunkDuration: TimeInterval = 10

    struct Recording: Codable, Identifiable {
        let id: UUID
        let startedAt: Date
        let backupAt: Date
        let systemVersion: String
        let firmware: String?
        let detectorVersion: String
        var endedAt: Date?
        var endReason: String?
        var wakeupEstimate: AthenaWakeDetector.Estimate?
        var confirmedWakeup: Date?
        var usedMuseEstimate: Bool?
    }

    struct Frame {
        private var payload = Data()

        mutating func addEEG(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
            payload.append(1)
            for sample in [a, b, c, d] {
                let code = Int((sample * 16383 / 1450 + 8192).rounded())
                payload.appendInteger(UInt16(max(0, min(16383, code))))
            }
        }

        mutating func addMotion(_ magnitude: Double) {
            payload.append(2)
            payload.appendInteger(Float(magnitude).bitPattern)
        }

        fileprivate func append(to data: inout Data, at date: Date) {
            guard !payload.isEmpty else { return }
            data.appendInteger(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
            data.appendInteger(UInt32(payload.count))
            data.append(payload)
        }

        var isEmpty: Bool { payload.isEmpty }
    }

    private let directory: URL
    private var recording: Recording
    private var chunkURLs: [URL]
    private var chunk = Data()
    private var chunkStart: Date?

    static func storageDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return support.appendingPathComponent("MuseOvernightDiagnostics", isDirectory: true)
    }

    static func completedRecordings(in root: URL) -> [Recording] {
        guard let directories = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }
        return directories.compactMap { directory -> Recording? in
            guard let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
                  let recording = try? JSONDecoder.overnightDiagnostics.decode(Manifest.self, from: data).recording,
                  directory.lastPathComponent == recording.id.uuidString,
                  recording.endedAt != nil else { return nil }
            return recording
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    static func recordingDirectory(_ id: UUID, in root: URL) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func addWakeupConfirmation(
        recordingID: UUID, in root: URL, at wakeup: Date, usedMuseEstimate: Bool
    ) throws {
        let url = recordingDirectory(recordingID, in: root).appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var manifest = try JSONDecoder.overnightDiagnostics.decode(Manifest.self, from: Data(contentsOf: url))
        guard manifest.recording.endedAt != nil else { return }
        manifest.recording.confirmedWakeup = wakeup
        manifest.recording.usedMuseEstimate = usedMuseEstimate
        try writeManifest(manifest, to: url)
    }

    init(recording: Recording, in root: URL) throws {
        self.recording = recording
        directory = Self.recordingDirectory(recording.id, in: root)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        var storage = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try storage.setResourceValues(values)
        #endif
        let manifestURL = directory.appendingPathComponent("manifest.json")
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            let manifest = try JSONDecoder.overnightDiagnostics.decode(Manifest.self, from: Data(contentsOf: manifestURL))
            guard manifest.recording.endedAt == nil else { throw CocoaError(.fileWriteFileExists) }
            self.recording = manifest.recording
        }
        chunkURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "bin" }
        try writeManifest()
    }

    func append(_ frame: Frame, at date: Date) throws {
        guard !frame.isEmpty else { return }
        if let chunkStart, date.timeIntervalSince(chunkStart) >= Self.chunkDuration || date < chunkStart {
            try flush()
            try trim(at: date)
        }
        if chunkStart == nil { chunkStart = date }
        frame.append(to: &chunk, at: date)
    }

    func checkpoint(at date: Date) throws {
        try flush()
        try trim(at: date)
    }

    func finish(
        at date: Date, reason: String, estimate: AthenaWakeDetector.Estimate?,
        confirmedWakeup: Date?, usedMuseEstimate: Bool?
    ) throws {
        try checkpoint(at: date)
        recording.endedAt = date
        recording.endReason = reason
        recording.wakeupEstimate = estimate
        recording.confirmedWakeup = confirmedWakeup
        recording.usedMuseEstimate = usedMuseEstimate
        try writeManifest()
    }

    private func flush() throws {
        guard let chunkStart, !chunk.isEmpty else { return }
        let micros = Int64((chunkStart.timeIntervalSince1970 * 1_000_000).rounded())
        let url = directory.appendingPathComponent("\(micros)-\(UUID().uuidString).bin")
        try chunk.write(to: url, options: Self.writeOptions)
        chunkURLs.append(url)
        chunk.removeAll(keepingCapacity: true)
        self.chunkStart = nil
    }

    private func trim(at date: Date) throws {
        let cutoff = Int64((date.addingTimeInterval(-Self.retention).timeIntervalSince1970 * 1_000_000).rounded())
        let expired = chunkURLs.filter { url in
            guard let prefix = url.lastPathComponent.split(separator: "-").first,
                  let micros = Int64(prefix) else { return false }
            return micros < cutoff
        }
        for url in expired {
            try FileManager.default.removeItem(at: url)
            chunkURLs.removeAll { $0 == url }
        }
    }

    private func writeManifest() throws {
        try Self.writeManifest(Manifest(recording: recording), to: directory.appendingPathComponent("manifest.json"))
    }

    private static func writeManifest(_ manifest: Manifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: url, options: writeOptions)
    }

    private static var writeOptions: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        .atomic
        #endif
    }

    private struct Manifest: Codable {
        var recording: Recording
        var formatVersion = 1
        var sampleRateHz = AthenaWakeDetector.sampleRate
        var channelOrder = AthenaWakeDetector.electrodeNames
        var retentionSeconds = MuseOvernightDiagnostics.retention
        var filterCenterHz = Athena50HzNotch.centerFrequency
        var filterBandwidthHz = Athena50HzNotch.bandwidth
        var recordingTimestampUnits = "Unix milliseconds"
        var binaryLayout = "Little-endian. Process .bin files by numeric filename prefix. Each frame: int64 Unix microseconds (host receipt time), uint32 payload byte length, then events. Event 1: uint8 tag 1 followed by four uint16 raw EEG codes in channel order; microvolts = (code - 8192) * 1450 / 16383. Event 2: uint8 tag 2 followed by float32 gyroscope magnitude in degrees/second. Samples within a frame share its timestamp."
    }
}

private extension Data {
    mutating func appendInteger<T: FixedWidthInteger>(_ value: T) {
        var bytes = value.littleEndian
        Swift.withUnsafeBytes(of: &bytes) { append(contentsOf: $0) }
    }
}

private extension JSONDecoder {
    static var overnightDiagnostics: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
