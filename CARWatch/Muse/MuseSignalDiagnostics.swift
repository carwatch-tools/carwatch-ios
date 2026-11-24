import Foundation

final class MuseSignalDiagnostics {
    static let maximumDuration: TimeInterval = 5 * 60
    private let maximumWindows = 600

    private struct Window: Encodable {
        let elapsedSeconds: Double
        let receiveSpanSeconds: Double
        let secondsSinceMotion: Double?
        let notificationsSincePreviousWindow: Int
        let longestNotificationGapSeconds: Double?
        let channels: [String: AthenaWakeDetector.ChannelDiagnostics]
        let filteredChannels: [String: AthenaWakeDetector.ChannelDiagnostics]
    }

    private struct Report: Encodable {
        let formatVersion: Int
        let detectorVersion = AthenaWakeDetector.version
        let firmware: String?
        let systemVersion: String
        let durationSeconds: Double
        let notifications: Int
        let decodedEEGSamplesPerChannel: Int
        let secondsSinceLastEEGAtEnd: Double?
        let windows: [Window]
        let filterTest: MuseNotchFilterTest?
    }

    private let startedAt: Date
    private let initialFirmware: String?
    private var lastNotification: Date?
    private var lastEEG: Date?
    private var notificationCount = 0
    private var eegSamples = 0
    private var windowNotificationCount = 0
    private var windowLongestGap: Double?
    private var windows: [Window] = []
    private var filterTest: MuseNotchFilterTest?

    init(startedAt: Date, firmware: String?, recordFilterTest: Bool = false) {
        self.startedAt = startedAt
        initialFirmware = firmware
        if recordFilterTest { filterTest = MuseNotchFilterTest() }
    }

    func canContinue(at date: Date) -> Bool {
        guard date.timeIntervalSince(startedAt) < Self.maximumDuration else { return false }
        if let filterTest { return !filterTest.isFull }
        return windows.count < maximumWindows
    }

    func receiveNotification(at date: Date) {
        if let lastNotification {
            let gap = date.timeIntervalSince(lastNotification)
            windowLongestGap = max(windowLongestGap ?? gap, gap)
        }
        lastNotification = date
        notificationCount += 1
        windowNotificationCount += 1
    }

    func receiveEEG(samples: Int, at date: Date) {
        guard samples > 0 else { return }
        eegSamples += samples
        lastEEG = date
    }

    func appendFilterTestSample(
        _ a: Double, _ b: Double, _ c: Double, _ d: Double,
        at date: Date, startsNotification: Bool
    ) {
        guard filterTest != nil else { return }
        filterTest?.append(a, b, c, d, elapsed: date.timeIntervalSince(startedAt), startsNotification: startsNotification)
    }

    func markFitChange(at date: Date) {
        filterTest?.markFitChange(elapsed: date.timeIntervalSince(startedAt))
    }

    func append(_ window: AthenaWakeDetector.WindowDiagnostics) {
        guard windows.count < maximumWindows else { return }
        windows.append(Window(
            elapsedSeconds: window.receivedAt.timeIntervalSince(startedAt),
            receiveSpanSeconds: window.receiveSpanSeconds,
            secondsSinceMotion: window.secondsSinceMotion,
            notificationsSincePreviousWindow: windowNotificationCount,
            longestNotificationGapSeconds: windowLongestGap,
            channels: window.channels, filteredChannels: window.filteredChannels
        ))
        windowNotificationCount = 0
        windowLongestGap = nil
    }

    func finish(at date: Date, firmware: String?, systemVersion: String) throws -> Data {
        let report = Report(
            formatVersion: filterTest == nil ? 1 : 2,
            firmware: firmware ?? initialFirmware, systemVersion: systemVersion,
            durationSeconds: date.timeIntervalSince(startedAt),
            notifications: notificationCount, decodedEEGSamplesPerChannel: eegSamples,
            secondsSinceLastEEGAtEnd: lastEEG.map { date.timeIntervalSince($0) },
            windows: windows, filterTest: filterTest
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = filterTest == nil ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(report)
    }
}

private struct MuseNotchFilterTest: Encodable {
    private static let maximumSamples = Int(MuseSignalDiagnostics.maximumDuration) * AthenaWakeDetector.sampleRate

    struct NotificationStart: Encodable {
        let sampleIndex: Int
        let elapsedSeconds: Double
        let filterReset: Bool
    }

    let sampleRateHz = AthenaWakeDetector.sampleRate
    let centerFrequencyHz = Athena50HzNotch.centerFrequency
    let filterQ = Athena50HzNotch.qualityFactor
    let bandwidthHz = Athena50HzNotch.bandwidth
    let filterResetGapSeconds = Athena50HzNotch.resetGap
    let channelOrder = AthenaWakeDetector.electrodeNames
    private(set) var rawMicrovolts = Array(repeating: [Double](), count: AthenaWakeDetector.electrodeNames.count)
    private(set) var filteredMicrovolts = Array(repeating: [Double](), count: AthenaWakeDetector.electrodeNames.count)
    private(set) var notificationStarts: [NotificationStart] = []
    private(set) var fitChangeMarkersElapsedSeconds: [Double] = []

    private var filters = Array(repeating: Athena50HzNotch(), count: AthenaWakeDetector.electrodeNames.count)

    private enum CodingKeys: String, CodingKey {
        case sampleRateHz, centerFrequencyHz, filterQ, bandwidthHz, filterResetGapSeconds, channelOrder
        case rawMicrovolts, filteredMicrovolts, notificationStarts, fitChangeMarkersElapsedSeconds
    }

    var isFull: Bool { rawMicrovolts[0].count >= Self.maximumSamples }

    mutating func append(
        _ a: Double, _ b: Double, _ c: Double, _ d: Double,
        elapsed: TimeInterval, startsNotification: Bool
    ) {
        guard !isFull else { return }
        let values = [a, b, c, d]
        if startsNotification {
            let reset = notificationStarts.last.map { abs(elapsed - $0.elapsedSeconds) > Athena50HzNotch.resetGap } ?? true
            notificationStarts.append(NotificationStart(
                sampleIndex: rawMicrovolts[0].count, elapsedSeconds: elapsed, filterReset: reset
            ))
            if reset {
                for channel in filters.indices {
                    filters[channel].reset(to: values[channel])
                }
            }
        }
        for channel in filters.indices {
            let sample = values[channel]
            let filtered = filters[channel].process(sample)
            rawMicrovolts[channel].append(sample)
            filteredMicrovolts[channel].append(filtered)
        }
    }

    mutating func markFitChange(elapsed: TimeInterval) {
        fitChangeMarkersElapsedSeconds.append(elapsed)
    }
}
