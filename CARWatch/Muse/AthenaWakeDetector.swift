import Foundation

// Wire format: OpenMuse's public Athena protocol documentation.
enum AthenaPacket {
    static func decode(
        _ data: Data,
        eeg: (Double, Double, Double, Double) -> Void,
        motion: (Double) -> Void,
        battery: (Int) -> Void
    ) {
        let bytes = Array(data)
        guard bytes.count > 14 else { return }
        var tag = bytes[9]
        var offset = 14

        while offset < bytes.count {
            let length: Int
            switch tag {
            case 0x11, 0x12: length = 28
            case 0x34: length = 30
            case 0x35, 0x36: length = 40
            case 0x47: length = 36
            case 0x53: length = 24
            case 0x88: length = 188
            case 0x98: length = 20
            default: return
            }
            let end = offset + length
            guard end <= bytes.count else { return }

            switch tag {
            case 0x11, 0x12:
                let channels = tag == 0x11 ? 4 : 8
                for sample in 0..<(16 / channels) {
                    func electrode(_ channel: Int) -> Double {
                        let bit = (sample * channels + channel) * 14
                        let index = offset + bit / 8
                        var word = UInt32(bytes[index]) | UInt32(bytes[index + 1]) << 8
                        if index + 2 < end { word |= UInt32(bytes[index + 2]) << 16 }
                        let value = (word >> (bit % 8)) & 0x3fff
                        return (Double(value) - 8192) * 1450 / 16383
                    }
                    eeg(electrode(0), electrode(1), electrode(2), electrode(3))
                }
            case 0x47:
                for sample in 0..<3 {
                    let start = offset + sample * 12 + 6
                    let magnitudeSquared = stride(from: start, to: start + 6, by: 2).reduce(0.0) { sum, index in
                        let value = Double(signedWord(bytes, at: index)) * 0.0074768
                        return sum + value * value
                    }
                    motion(magnitudeSquared.squareRoot())
                }
            case 0x88, 0x98:
                let percent = Int((Double(UInt16(bitPattern: signedWord(bytes, at: offset))) / 256).rounded())
                if (0...100).contains(percent) { battery(percent) }
                if tag == 0x88 { return } // This firmware's battery payload has a variable length.
            default:
                break
            }

            guard end + 5 < bytes.count else { return }
            tag = bytes[end]
            offset = end + 5
        }
    }

    private static func signedWord(_ bytes: [UInt8], at offset: Int) -> Int16 {
        Int16(bitPattern: UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8)
    }
}

// Pilot heuristic. Thresholds require validation against independently scored wake times.
final class AthenaWakeDetector {
    static let version = "athena-pilot-3"
    static let wakeWindow: TimeInterval = 90 * 60
    static let minimumSession: TimeInterval = 2 * 60 * 60

    struct Estimate: Codable, Equatable {
        let onset: Date
        let detectedAt: Date
    }

    enum ChannelQuality: String, Codable {
        case usable
        case flat
        case clipped
        case largeSwings
        case electricalNoise
    }

    static let electrodeNames = ["TP9", "AF7", "AF8", "TP10"]

    struct ChannelDiagnostics: Encodable {
        let quality: ChannelQuality
        let minimumMicrovolts: Double
        let maximumMicrovolts: Double
        let peakToPeakMicrovolts: Double
        let slowBandPower: Double
        let fastBandPower: Double
        let powerAround50Hz: Double
        let powerAround60Hz: Double
    }

    struct WindowDiagnostics {
        let receivedAt: Date
        let receiveSpanSeconds: Double
        let secondsSinceMotion: Double?
        let channels: [String: ChannelDiagnostics]
        let filteredChannels: [String: ChannelDiagnostics]
    }

    private struct ChannelAnalysis {
        let quality: ChannelQuality
        var slow = 0.0
        var fast = 0.0
        var diagnostics: ChannelDiagnostics?
    }

    static let sampleRate = 256
    private static let slowBand = 1...7
    private static let fastBand = 8...30
    private static let mainsBands = [49...51, 59...61]
    private static let coefficients = (0...61).map {
        2 * cos(2 * .pi * Double($0) / Double(sampleRate))
    }
    private static let window = (0..<sampleRate).map {
        0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(sampleRate))
    }
    private var rawChannels = Array(repeating: [Double](), count: 4)
    private var filteredChannels = Array(repeating: [Double](), count: 4)
    private var filters = Array(repeating: Athena50HzNotch(), count: 4)
    private var lastEEG: Date?
    private var lastMotion: Date?
    private var lastMovement: Date?
    private var secondStartedAt: Date?
    private var sleepSeconds = 0
    private var sleepEstablished = false
    private var unusableSeconds = 0
    private var wakeSeconds = 0
    private var wakeStart: Date?
    private(set) var channelQuality: [ChannelQuality] = []

    func reset() {
        clearWindow()
        channelQuality = []
        lastEEG = nil
        lastMotion = nil
        lastMovement = nil
        sleepSeconds = 0
        sleepEstablished = false
        unusableSeconds = 0
        wakeSeconds = 0
        wakeStart = nil
    }

    func addMotion(_ degreesPerSecond: Double, at date: Date) {
        lastMotion = date
        if degreesPerSecond >= 15 { lastMovement = date }
    }

    func addEEG(
        _ a: Double, _ b: Double, _ c: Double, _ d: Double,
        at date: Date, detectionFrom: Date?,
        diagnostics: ((WindowDiagnostics) -> Void)? = nil
    ) -> Estimate? {
        let gap = lastEEG.map { abs(date.timeIntervalSince($0)) }
        if let gap, gap > 3 { reset() }

        let samples = [a, b, c, d]
        if (gap ?? .infinity) > Athena50HzNotch.resetGap {
            clearWindow()
            channelQuality = []
            sleepSeconds = 0
            resetWakeRun()
            for channel in filters.indices {
                filters[channel].reset(to: samples[channel])
            }
        }

        lastEEG = date
        if secondStartedAt == nil { secondStartedAt = date }
        for channel in filters.indices {
            let sample = samples[channel]
            rawChannels[channel].append(sample)
            filteredChannels[channel].append(filters[channel].process(sample))
        }
        guard rawChannels[0].count == Self.sampleRate, let secondStartedAt else { return nil }

        let secondsElapsed = date.timeIntervalSince(secondStartedAt)
        let analysis = zip(rawChannels, filteredChannels).map { raw, filtered in
            Self.analyze(filtered, includeDiagnostics: diagnostics != nil, rawClipped: raw.contains(where: Self.isClipped))
        }
        let features = analysis.filter { $0.quality == .usable }
        channelQuality = analysis.map(\.quality)

        if let diagnostics {
            let raw = rawChannels.compactMap { Self.analyze($0, includeDiagnostics: true).diagnostics }
            diagnostics(WindowDiagnostics(
                receivedAt: date,
                receiveSpanSeconds: secondsElapsed,
                secondsSinceMotion: lastMotion.map { date.timeIntervalSince($0) },
                channels: Dictionary(uniqueKeysWithValues: zip(Self.electrodeNames, raw)),
                filteredChannels: Dictionary(uniqueKeysWithValues: zip(Self.electrodeNames, analysis.compactMap(\.diagnostics)))
            ))
        }
        clearWindow()

        guard features.count >= 2, (0.5...1.5).contains(secondsElapsed),
              let lastMotion, abs(date.timeIntervalSince(lastMotion)) < 3 else {
            unusableSeconds += 1
            if unusableSeconds >= 15 { sleepEstablished = false }
            sleepSeconds = 0
            resetWakeRun()
            return nil
        }

        unusableSeconds = 0
        let moving = lastMovement.map { abs(date.timeIntervalSince($0)) <= 3 } ?? false
        let sleepLike = features.filter { $0.slow >= $0.fast * 3 }.count >= 2 && !moving
        let wakeLike = features.filter { $0.fast >= $0.slow }.count >= 2
        if sleepLike {
            sleepSeconds += 1
            if sleepSeconds >= 150 { sleepEstablished = true }
        } else {
            sleepSeconds = 0
        }

        guard let detectionFrom, secondStartedAt >= detectionFrom, sleepEstablished, wakeLike else {
            resetWakeRun()
            return nil
        }
        if wakeStart == nil { wakeStart = secondStartedAt }
        wakeSeconds += 1
        guard wakeSeconds >= 60, let wakeStart, let lastMovement,
              date.timeIntervalSince(lastMovement) < 120 else { return nil }
        return Estimate(onset: wakeStart, detectedAt: date)
    }

    private func clearWindow() {
        for channel in filters.indices {
            rawChannels[channel].removeAll(keepingCapacity: true)
            filteredChannels[channel].removeAll(keepingCapacity: true)
        }
        secondStartedAt = nil
    }

    private func resetWakeRun() {
        wakeSeconds = 0
        wakeStart = nil
    }

    private static func isClipped(_ sample: Double) -> Bool {
        abs(sample) >= 700
    }

    private static func analyze(
        _ samples: [Double], includeDiagnostics: Bool, rawClipped: Bool = false
    ) -> ChannelAnalysis {
        let low = samples.min() ?? 0
        let high = samples.max() ?? 0
        let peakToPeak = high - low
        let amplitudeRejection: ChannelQuality?
        if rawClipped || isClipped(low) || isClipped(high) {
            amplitudeRejection = .clipped
        } else if peakToPeak < 4 {
            amplitudeRejection = .flat
        } else if peakToPeak > 250 {
            amplitudeRejection = .largeSwings
        } else {
            amplitudeRejection = nil
        }
        if let amplitudeRejection, !includeDiagnostics {
            return ChannelAnalysis(quality: amplitudeRejection)
        }

        // Include all frequency bins in each band so an ordinary EEG peak
        // between the old test frequencies can contribute to signal quality.
        let mean = samples.reduce(0, +) / Double(samples.count)
        let tapered = zip(samples, window).map { ($0 - mean) * $1 }
        func power(in band: ClosedRange<Int>) -> Double {
            band.reduce(0.0) { total, frequency in
                let coefficient = coefficients[frequency]
                var previous = 0.0
                var older = 0.0
                for sample in tapered {
                    let next = sample + coefficient * previous - older
                    older = previous
                    previous = next
                }
                return total + previous * previous + older * older - coefficient * previous * older
            }
        }
        let slow = power(in: slowBand)
        let fast = power(in: fastBand)
        let powerAround50Hz = power(in: mainsBands[0])
        let powerAround60Hz = power(in: mainsBands[1])
        let mains = max(powerAround50Hz, powerAround60Hz)
        let quality = amplitudeRejection ?? (slow + fast > 0 && mains < slow + fast ? .usable : .electricalNoise)
        var result = ChannelAnalysis(quality: quality, slow: slow, fast: fast)
        if includeDiagnostics {
            result.diagnostics = ChannelDiagnostics(
                quality: quality, minimumMicrovolts: low, maximumMicrovolts: high,
                peakToPeakMicrovolts: peakToPeak, slowBandPower: slow, fastBandPower: fast,
                powerAround50Hz: powerAround50Hz, powerAround60Hz: powerAround60Hz
            )
        }
        return result
    }
}

// Unity-gain, second-order notch in transposed direct form II.
struct Athena50HzNotch {
    static let centerFrequency = 50.0
    static let qualityFactor = 10.0
    static let bandwidth = centerFrequency / qualityFactor
    static let resetGap: TimeInterval = 0.5

    private static let sampleRate = Double(AthenaWakeDetector.sampleRate)
    private static let omega = 2 * .pi * centerFrequency / sampleRate
    // Match the digital bandwidth used in the offline replay.
    private static let beta = tan(.pi * bandwidth / sampleRate)
    private static let b0 = 1 / (1 + beta)
    private static let b1 = -2 * cos(omega) / (1 + beta)
    private static let a2 = (1 - beta) / (1 + beta)

    private var z1 = 0.0
    private var z2 = 0.0

    mutating func reset(to sample: Double) {
        z1 = (1 - Self.b0) * sample
        z2 = (Self.b0 - Self.a2) * sample
    }

    mutating func process(_ sample: Double) -> Double {
        let output = Self.b0 * sample + z1
        z1 = Self.b1 * (sample - output) + z2
        z2 = Self.b0 * sample - Self.a2 * output
        return output
    }
}
