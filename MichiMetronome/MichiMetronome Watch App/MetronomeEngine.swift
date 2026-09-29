import AVFoundation
import Combine
import Darwin
import Foundation
import UserNotifications
import WatchKit

private nonisolated final class HapticOutput: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.michi0403.michimetronome.haptics",
        qos: .userInteractive
    )

    private let lock = NSLock()

    private var inFlight = false
    private var cooldownUntil: TimeInterval = 0

    func requestClick() {
        let now = ProcessInfo.processInfo.systemUptime

        lock.lock()

        guard
            !inFlight,
            now >= cooldownUntil
        else {
            lock.unlock()
            return
        }

        inFlight = true
        lock.unlock()

        queue.async { [weak self] in
            guard let self else {
                return
            }

            let started = ProcessInfo.processInfo.systemUptime

            WKInterfaceDevice.current().play(.click)

            let elapsed =
                ProcessInfo.processInfo.systemUptime
                - started

            self.lock.lock()

            self.inFlight = false

            // WatchKit provides no "haptic engine ready" API.
            // If starting it blocks, back off rather than hammering it
            // every beat and building a delayed queue.
            if elapsed > 0.20 {
                self.cooldownUntil =
                    ProcessInfo.processInfo.systemUptime
                    + 5.0
            }

            self.lock.unlock()
        }
    }
}


private nonisolated struct MicrophoneFrame: Sendable {
    let timestamp: TimeInterval
    let rms: Double
    let frequency: Double?
    let midiValue: Double?
    let midiNote: Int?
    let cents: Double?
    let confidence: Double
    let onset: Bool
}

private nonisolated enum MicrophoneCaptureError: LocalizedError {
    case permissionDenied
    case noInput
    case startFailed(String)
    case activationFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone permission is required."
        case .noInput:
            "No usable microphone input is available."
        case .startFailed(let message):
            "Microphone could not start: \(message)"
        case .activationFailed(let message):
            "Microphone audio session could not activate: \(message)"
        }
    }
}

private nonisolated final class MicrophoneAnalyzer: @unchecked Sendable {
    typealias FrameHandler =
        @Sendable (MicrophoneFrame) -> Void

    typealias Completion =
        @Sendable (Result<Void, Error>) -> Void

    private let controlQueue = DispatchQueue(
        label:
            "com.michi0403.michimetronome.microphone.control",
        qos: .userInitiated
    )

    private let analysisQueue = DispatchQueue(
        label:
            "com.michi0403.michimetronome.microphone.analysis",
        qos: .userInitiated
    )

    // Only one copied microphone block may wait for analysis at a time.
    // This prevents a slow Watch CPU from building an unbounded queue of
    // PCM arrays while the real-time audio callback keeps arriving.
    private let analysisGate =
        DispatchSemaphore(value: 1)

    private var engine: AVAudioEngine?
    private var running = false
    private var starting = false

    // Analysis state lives only on analysisQueue.
    private var smoothedRMS = 0.0
    private var previousRMS = 0.0
    private var lastOnsetTime = -Double.infinity
    private var lastTrackedMidiValue: Double?
    private var lastEmittedMidiNote: Int?
    private var lastAnalysisTime = -Double.infinity

    func start(
        onFrame: @escaping FrameHandler,
        completion: @escaping Completion
    ) {
        controlQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.running {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
            }

            guard !self.starting else {
                return
            }

            self.starting = true

            AVAudioApplication
                .requestRecordPermission {
                    [weak self] granted in

                    guard let self else {
                        return
                    }

                    self.controlQueue.async {
                        guard granted else {
                            self.starting = false

                            DispatchQueue.main.async {
                                completion(
                                    .failure(
                                        MicrophoneCaptureError
                                            .permissionDenied
                                    )
                                )
                            }
                            return
                        }

                        let session =
                            AVAudioSession.sharedInstance()

                        do {
                            // Keep recording isolated from Watch speaker output.
                            // The metronome playback session is explicitly
                            // deactivated before this path starts.
                            try session.setCategory(
                                .record,
                                mode: .measurement,
                                options: []
                            )
                        } catch {
                            self.starting = false

                            DispatchQueue.main.async {
                                completion(
                                    .failure(error)
                                )
                            }
                            return
                        }

                        // watchOS has a dedicated asynchronous activation path.
                        // Waiting for the actual activation result avoids the
                        // playback->record priority race seen on second use.
                        session.activate {
                            [weak self]
                            activated,
                            activationError in

                            guard let self else {
                                return
                            }

                            self.controlQueue.async {
                                guard
                                    activated,
                                    activationError == nil
                                else {
                                    self.starting = false

                                    let message =
                                        activationError?
                                            .localizedDescription
                                        ?? "The audio session was not activated."

                                    DispatchQueue.main.async {
                                        completion(
                                            .failure(
                                                MicrophoneCaptureError
                                                    .activationFailed(
                                                        message
                                                    )
                                            )
                                        )
                                    }
                                    return
                                }

                                do {
                                    try self.startEngine(
                                        onFrame: onFrame
                                    )

                                    self.running = true
                                    self.starting = false

                                    DispatchQueue.main.async {
                                        completion(
                                            .success(())
                                        )
                                    }
                                } catch {
                                    self.running = false
                                    self.starting = false

                                    try? session.setActive(
                                        false,
                                        options: [
                                            .notifyOthersOnDeactivation
                                        ]
                                    )

                                    DispatchQueue.main.async {
                                        completion(
                                            .failure(error)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }

    func stop(
        completion: (@Sendable () -> Void)? = nil
    ) {
        controlQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.starting = false

            if let engine = self.engine {
                engine.inputNode.removeTap(
                    onBus: 0
                )
                engine.stop()
                engine.reset()
            }

            self.engine = nil
            self.running = false

            self.analysisQueue.async {
                self.resetAnalysisState()
            }

            let session =
                AVAudioSession.sharedInstance()

            try? session.setActive(
                false,
                options: [
                    .notifyOthersOnDeactivation
                ]
            )

            // Xcode 26.6 deactivation is synchronous. Give watchOS a short
            // route/priority handoff window before playback is prepared again.
            self.controlQueue.asyncAfter(
                deadline: .now() + 0.06
            ) {
                if let completion {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        }
    }

    private func startEngine(
        onFrame: @escaping FrameHandler
    ) throws {
        let audioEngine = AVAudioEngine()
        let input = audioEngine.inputNode
        let format =
            input.outputFormat(forBus: 0)

        guard
            format.sampleRate > 0,
            format.channelCount > 0
        else {
            throw MicrophoneCaptureError.noInput
        }

        analysisQueue.async {
            self.resetAnalysisState()
        }

        input.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) {
            [weak self] buffer, _ in

            guard
                let self,
                let channel =
                    buffer.floatChannelData?[0]
            else {
                return
            }

            let count =
                Int(buffer.frameLength)

            guard count > 0 else {
                return
            }

            // Never let analysis work queue up behind the real-time tap.
            // If the previous block is still being processed, drop this block
            // rather than increasing latency and eventually hanging the UI.
            guard
                self.analysisGate.wait(
                    timeout: .now()
                ) == .success
            else {
                return
            }

            // Copy immediately off the audio callback's temporary buffer.
            let samples = Array(
                UnsafeBufferPointer(
                    start: channel,
                    count: count
                )
            )

            let timestamp =
                ProcessInfo.processInfo
                    .systemUptime

            let sampleRate =
                format.sampleRate

            self.analysisQueue.async {
                defer {
                    self.analysisGate.signal()
                }

                guard
                    timestamp
                        - self.lastAnalysisTime
                        >= 0.018
                else {
                    return
                }

                self.lastAnalysisTime =
                    timestamp

                let frame =
                    self.analyze(
                        samples: samples,
                        sampleRate:
                            sampleRate,
                        timestamp:
                            timestamp
                    )

                onFrame(frame)
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)

            throw MicrophoneCaptureError
                .startFailed(
                    error.localizedDescription
                )
        }

        engine = audioEngine
    }

    private func resetAnalysisState() {
        smoothedRMS = 0
        previousRMS = 0
        lastOnsetTime = -Double.infinity
        lastTrackedMidiValue = nil
        lastEmittedMidiNote = nil
        lastAnalysisTime = -Double.infinity
    }

    private func analyze(
        samples: [Float],
        sampleRate: Double,
        timestamp: TimeInterval
    ) -> MicrophoneFrame {
        guard !samples.isEmpty else {
            return MicrophoneFrame(
                timestamp: timestamp,
                rms: 0,
                frequency: nil,
                midiValue: nil,
                midiNote: nil,
                cents: nil,
                confidence: 0,
                onset: false
            )
        }

        var sumSquares = 0.0
        var mean = 0.0

        for sample in samples {
            let value = Double(sample)
            mean += value
            sumSquares += value * value
        }

        mean /= Double(samples.count)

        let rms = sqrt(
            sumSquares
            / Double(samples.count)
        )

        // Reduce the analysis rate to roughly 12 kHz. For tuner use this
        // preserves more than enough bandwidth while keeping the Watch CPU low.
        let decimation = max(
            1,
            Int(sampleRate / 12_000.0)
        )

        let effectiveRate =
            sampleRate
            / Double(decimation)

        var reduced: [Double] = []
        reduced.reserveCapacity(
            samples.count / decimation + 1
        )

        var index = 0

        while index < samples.count {
            reduced.append(
                Double(samples[index])
                - mean
            )

            index += decimation
        }

        let pitch =
            estimatePitch(
                samples: reduced,
                sampleRate:
                    effectiveRate,
                rms: rms
            )

        let midiValue: Double?
        let midiNote: Int?
        let cents: Double?

        if
            let frequency = pitch.frequency
        {
            let value =
                69.0
                + 12.0
                * log2(
                    frequency / 440.0
                )

            let nearest =
                Int(value.rounded())

            midiValue = value
            midiNote =
                min(max(nearest, 0), 127)
            cents =
                (value
                    - Double(nearest))
                * 100.0
        } else {
            midiValue = nil
            midiNote = nil
            cents = nil
        }

        let previousEnvelope =
            max(
                smoothedRMS,
                0.0015
            )

        smoothedRMS =
            smoothedRMS * 0.86
            + rms * 0.14

        let confidentPitch =
            midiNote != nil
            && pitch.confidence >= 0.50
            && rms >= 0.008

        let amplitudeAttack =
            rms >= 0.009
            && rms
                > max(
                    previousRMS * 1.28,
                    previousEnvelope * 1.35
                )

        // Compare against the last note that was actually EMITTED as an onset,
        // not merely the most recently displayed tuner value.
        //
        // This is important for fast playing: if a pitch changes during the
        // short refractory window, the change remains pending until it can be
        // accepted instead of disappearing on the next analysis frame.
        let noteChange: Bool

        if
            confidentPitch,
            let midiNote,
            let midiValue,
            let lastEmittedMidiNote
        {
            noteChange =
                midiNote != lastEmittedMidiNote
                && abs(
                    midiValue
                    - Double(lastEmittedMidiNote)
                ) >= 0.60
        } else {
            noteChange = false
        }

        let firstConfidentNote =
            confidentPitch
            && lastEmittedMidiNote == nil

        // 65 ms still rejects duplicate flutter, but permits roughly
        // 15 note attacks per second when the pitch detector can resolve them.
        let enoughGap =
            timestamp
            - lastOnsetTime
            >= 0.065

        let onset =
            enoughGap
            && (
                firstConfidentNote
                || amplitudeAttack
                || noteChange
            )

        if onset {
            lastOnsetTime =
                timestamp

            if let midiNote {
                lastEmittedMidiNote =
                    midiNote
            }
        }

        if
            let midiValue,
            pitch.confidence >= 0.48
        {
            lastTrackedMidiValue =
                midiValue
        }

        previousRMS = rms

        return MicrophoneFrame(
            timestamp: timestamp,
            rms: rms,
            frequency:
                pitch.frequency,
            midiValue: midiValue,
            midiNote: midiNote,
            cents: cents,
            confidence:
                pitch.confidence,
            onset: onset
        )
    }

    private func estimatePitch(
        samples: [Double],
        sampleRate: Double,
        rms: Double
    ) -> (
        frequency: Double?,
        confidence: Double
    ) {
        guard
            rms >= 0.006,
            samples.count >= 256
        else {
            return (nil, 0)
        }

        let minimumFrequency = 55.0
        let maximumFrequency = 1_760.0

        let minimumLag =
            max(
                2,
                Int(
                    sampleRate
                    / maximumFrequency
                )
            )

        let maximumLag =
            min(
                samples.count / 2,
                Int(
                    sampleRate
                    / minimumFrequency
                )
            )

        guard
            maximumLag > minimumLag
        else {
            return (nil, 0)
        }

        var bestLag = 0
        var bestCorrelation = 0.0

        for lag in minimumLag...maximumLag {
            let count =
                samples.count - lag

            guard count > 32 else {
                continue
            }

            var cross = 0.0
            var energyA = 0.0
            var energyB = 0.0

            for index in 0..<count {
                let a = samples[index]
                let b =
                    samples[index + lag]

                cross += a * b
                energyA += a * a
                energyB += b * b
            }

            let denominator =
                sqrt(
                    energyA * energyB
                )

            guard denominator > 0 else {
                continue
            }

            let correlation =
                cross / denominator

            if correlation > bestCorrelation {
                bestCorrelation =
                    correlation
                bestLag = lag
            }
        }

        guard
            bestLag > 0,
            bestCorrelation >= 0.50
        else {
            return (
                nil,
                bestCorrelation
            )
        }

        let frequency =
            sampleRate
            / Double(bestLag)

        guard
            frequency
                >= minimumFrequency,
            frequency
                <= maximumFrequency
        else {
            return (nil, 0)
        }

        return (
            frequency,
            bestCorrelation
        )
    }
}

private nonisolated enum MusicalClock {
    // A MIDI-style musical resolution. We intentionally keep this internal
    // instead of depending on CoreMIDI/AVAudioSequencer, because Apple's
    // MIDI instrument/sequencer playback APIs are unavailable on watchOS.
    static let ticksPerBeat: Int64 = 960

    static func tick(
        forBeatIndex beatIndex: Int
    ) -> Int64 {
        Int64(max(beatIndex, 0))
            * ticksPerBeat
    }

    static func seconds(
        forTick tick: Int64,
        bpm: Double
    ) -> TimeInterval {
        let beats =
            Double(tick)
            / Double(ticksPerBeat)

        return beats
            * 60.0
            / max(bpm, 1)
    }
}

private nonisolated struct PlaybackPlan: Sendable {
    let mode: MetronomeMode
    let bpm: Double
    let beatsPerBar: Int
    let manualIntervals: [Double]
    let manualMidiNotes: [Int?]
    let baseMidiNote: Int
    let accentDownbeat: Bool
    let audioEnabled: Bool
    let hapticsEnabled: Bool
    let clickTone: ClickTone

    func step(
        for eventIndex: Int
    ) -> Int {
        switch mode {
        case .bpm:
            return eventIndex
                % max(beatsPerBar, 1)

        case .manual:
            guard
                !manualIntervals.isEmpty
            else {
                return 0
            }

            return eventIndex
                % manualIntervals.count
        }
    }

    func accent(
        for eventIndex: Int
    ) -> Bool {
        accentDownbeat
            && step(for: eventIndex) == 0
    }

    func recordedMidiNote(
        for eventIndex: Int
    ) -> Int? {
        guard
            mode == .manual,
            !manualIntervals.isEmpty,
            !manualMidiNotes.isEmpty
        else {
            return nil
        }

        let step =
            eventIndex
            % manualIntervals.count

        guard step < manualMidiNotes.count else {
            return nil
        }

        return manualMidiNotes[step]
    }

    func playbackMidiNote(
        for eventIndex: Int
    ) -> Int {
        recordedMidiNote(
            for: eventIndex
        ) ?? baseMidiNote
    }

    func noteDuration(
        for eventIndex: Int
    ) -> TimeInterval {
        switch mode {
        case .bpm:
            let beatDuration =
                60.0 / max(bpm, 1)

            return min(
                0.16,
                max(
                    0.055,
                    beatDuration * 0.42
                )
            )

        case .manual:
            guard !manualIntervals.isEmpty else {
                return 0.10
            }

            let interval =
                manualIntervals[
                    eventIndex
                    % manualIntervals.count
                ]

            return min(
                0.35,
                max(
                    0.035,
                    interval * 0.52
                )
            )
        }
    }

    /// Absolute musical time from the start of this playback.
    ///
    /// This is deliberately NOT calculated by repeatedly adding the previous
    /// interval. Every event is mapped independently from its musical position
    /// back to the start time, so long-running playback can't accumulate
    /// per-beat floating-point/host-time rounding error.
    func elapsedSeconds(
        for eventIndex: Int
    ) -> TimeInterval {
        let index = max(eventIndex, 0)

        switch mode {
        case .bpm:
            let tick =
                MusicalClock.tick(
                    forBeatIndex: index
                )

            return MusicalClock.seconds(
                forTick: tick,
                bpm: bpm
            )

        case .manual:
            guard
                !manualIntervals.isEmpty
            else {
                return 0
            }

            let count =
                manualIntervals.count

            let cycle =
                index / count

            let step =
                index % count

            let cycleDuration =
                manualIntervals.reduce(
                    0,
                    +
                )

            let stepOffset =
                manualIntervals
                    .prefix(step)
                    .reduce(0, +)

            return
                Double(cycle)
                    * cycleDuration
                + stepOffset
        }
    }

    func hostTime(
        for eventIndex: Int,
        startHostTime: UInt64
    ) -> UInt64 {
        startHostTime
            &+ AVAudioTime.hostTime(
                forSeconds:
                    elapsedSeconds(
                        for: eventIndex
                    )
            )
    }

    /// Returns the first event whose absolute position is not earlier
    /// than `hostTime`. This lets the live UI/haptic side skip straight
    /// over a system stall instead of replaying missed beats.
    func firstEventIndex(
        atOrAfter hostTime: UInt64,
        startHostTime: UInt64
    ) -> Int {
        guard
            hostTime > startHostTime
        else {
            return 0
        }

        let elapsed =
            AVAudioTime.seconds(
                forHostTime:
                    hostTime
                    - startHostTime
            )

        switch mode {
        case .bpm:
            let beatDuration =
                60.0 / max(bpm, 1)

            return max(
                0,
                Int(
                    ceil(
                        elapsed
                        / beatDuration
                        - 0.000_000_001
                    )
                )
            )

        case .manual:
            guard
                !manualIntervals.isEmpty
            else {
                return 0
            }

            let cycleDuration =
                manualIntervals.reduce(
                    0,
                    +
                )

            guard cycleDuration > 0 else {
                return 0
            }

            let count =
                manualIntervals.count

            let cycle =
                max(
                    0,
                    Int(
                        floor(
                            elapsed
                            / cycleDuration
                        )
                    )
                )

            let insideCycle =
                elapsed
                - Double(cycle)
                    * cycleDuration

            var offset = 0.0

            for step in 0..<count {
                if
                    offset
                    + 0.000_000_001
                    >= insideCycle
                {
                    return cycle
                        * count
                        + step
                }

                offset +=
                    manualIntervals[step]
            }

            return
                (cycle + 1)
                * count
        }
    }
}

@MainActor
final class MetronomeEngine: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPreparing = false
    @Published private(set) var beatIndex = 0
    @Published private(set) var settings: MetronomeSettings
    @Published private(set) var isRecordingManualPattern = false
    @Published private(set) var manualTapCount = 0
    @Published private(set) var lastBeatDate: Date?
    @Published private(set) var outputWarning: String?
    @Published private(set) var currentPlaybackMidiNote: Int?

    @Published private(set) var isPreparingMicrophone = false
    @Published private(set) var isRecordingMicrophonePattern = false
    @Published private(set) var isTunerActive = false
    @Published private(set) var microphoneError: String?
    @Published private(set) var detectedFrequency: Double?
    @Published private(set) var detectedMidiNote: Int?
    @Published private(set) var detectedCents: Double?
    @Published private(set) var microphoneLevel: Double = 0
    @Published private(set) var microphoneOnsetCount = 0

    private var playbackTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?

    private var generation: UInt64 = 0
    private var recordingTapTimes: [TimeInterval] = []
    private var microphoneOnsets: [
        (
            timestamp: TimeInterval,
            midiNote: Int?
        )
    ] = []

    private var resumeAfterForeground = false

    private let audio = ClickAudioEngine()
    private let haptics = HapticOutput()
    private let microphone = MicrophoneAnalyzer()

    init() {
        settings = SettingsStore.load()

        Task {
            await audio.setTone(settings.clickTone)
        }
    }

    deinit {
        playbackTask?.cancel()
        preparationTask?.cancel()
    }

    var canStart: Bool {
        guard !microphoneOwnsAudioSession else {
            return false
        }

        switch settings.mode {
        case .bpm:
            return true

        case .manual:
            return !settings.manualIntervals.isEmpty
        }
    }

    var manualCycleDuration: TimeInterval {
        settings.manualIntervals.reduce(0, +)
    }

    var manualBeatPositions: [Double] {
        let intervals = settings.manualIntervals
        let total = intervals.reduce(0, +)

        guard total > 0, !intervals.isEmpty else {
            return []
        }

        var elapsed = 0.0
        var positions: [Double] = []

        for interval in intervals {
            positions.append(elapsed / total)
            elapsed += interval
        }

        return positions
    }

    var manualApproximateBPM: Int? {
        guard !settings.manualIntervals.isEmpty else {
            return nil
        }

        let average =
            settings.manualIntervals.reduce(0, +)
            / Double(settings.manualIntervals.count)

        guard average > 0 else {
            return nil
        }

        return Int((60.0 / average).rounded())
    }

    var detectedNoteName: String? {
        guard let detectedMidiNote else {
            return nil
        }

        return Self.noteName(
            midiNote: detectedMidiNote
        )
    }

    var baseNoteName: String {
        Self.noteName(
            midiNote: settings.baseMidiNote
        )
    }

    var currentPlaybackNoteName: String? {
        guard let currentPlaybackMidiNote else {
            return nil
        }

        return Self.noteName(
            midiNote: currentPlaybackMidiNote
        )
    }

    var manualNoteSummary: String? {
        let names: [String] =
            settings.manualMidiNotes
                .compactMap {
                    (note: Int?) -> String? in

                    guard let note else {
                        return nil
                    }

                    return Self.noteName(
                        midiNote: note
                    )
                }

        guard !names.isEmpty else {
            return nil
        }

        return names.joined(
            separator: "  "
        )
    }

    private var microphoneOwnsAudioSession: Bool {
        isPreparingMicrophone
            || isRecordingMicrophonePattern
            || isTunerActive
    }

    func prepareForUse() {
        guard
            settings.audioEnabled,
            !microphoneOwnsAudioSession
        else {
            return
        }

        let tone = settings.clickTone

        Task {
            _ = await audio.prepareSession(tone: tone)
        }
    }

    func manualProgress(at date: Date) -> Double {
        guard
            isRunning,
            settings.mode == .manual,
            manualCycleDuration > 0,
            let lastBeatDate
        else {
            return 0
        }

        let positions = manualBeatPositions

        guard
            !positions.isEmpty,
            beatIndex < positions.count
        else {
            return 0
        }

        let cycle = manualCycleDuration
        let basePosition =
            positions[beatIndex] * cycle

        let elapsedSinceBeat = max(
            0,
            date.timeIntervalSince(lastBeatDate)
        )

        let raw =
            basePosition + elapsedSinceBeat

        return raw.truncatingRemainder(
            dividingBy: cycle
        ) / cycle
    }

    func toggle() {
        if isRunning || isPreparing {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard
            !isRunning,
            !isPreparing,
            !microphoneOwnsAudioSession,
            canStart
        else {
            return
        }

        generation &+= 1

        let expectedGeneration = generation
        let requestedSettings = settings

        isPreparing = true
        outputWarning = nil

        preparationTask?.cancel()

        preparationTask = Task { [weak self] in
            guard let self else {
                return
            }

            var audioReady = true

            if requestedSettings.audioEnabled {
                audioReady = await self.audio.prepareSession(
                    tone: requestedSettings.clickTone
                )
            }

            guard
                !Task.isCancelled,
                self.generation == expectedGeneration
            else {
                return
            }

            let effectiveAudio =
                requestedSettings.audioEnabled
                && audioReady

            if requestedSettings.audioEnabled,
               !audioReady {
                self.outputWarning =
                    requestedSettings.hapticsEnabled
                    ? "Audio could not become ready. Running haptic-only."
                    : "Audio could not become ready."
            }

            guard
                effectiveAudio
                || requestedSettings.hapticsEnabled
            else {
                self.isPreparing = false
                return
            }

            await self.audio.clearScheduledAudio()

            guard
                !Task.isCancelled,
                self.generation == expectedGeneration
            else {
                return
            }

            let plan = PlaybackPlan(
                mode: requestedSettings.mode,
                bpm: requestedSettings.bpm,
                beatsPerBar:
                    requestedSettings.beatsPerBar,
                manualIntervals:
                    requestedSettings.manualIntervals,
                manualMidiNotes:
                    requestedSettings.manualMidiNotes,
                baseMidiNote:
                    requestedSettings.baseMidiNote,
                accentDownbeat:
                    requestedSettings.accentDownbeat,
                audioEnabled: effectiveAudio,
                hapticsEnabled:
                    requestedSettings.hapticsEnabled,
                clickTone:
                    requestedSettings.clickTone
            )

            self.beatIndex = 0
            self.lastBeatDate = nil
            self.isPreparing = false
            self.isRunning = true

            // Give Core Audio a small scheduling runway. Nothing is emitted
            // before all required audio setup has completed.
            let startHostTime =
                mach_absolute_time()
                + AVAudioTime.hostTime(
                    forSeconds: 0.25
                )

            self.beginPlaybackLoop(
                plan: plan,
                generation: expectedGeneration,
                startHostTime: startHostTime
            )
        }
    }

    func stop() {
        generation &+= 1

        preparationTask?.cancel()
        preparationTask = nil

        playbackTask?.cancel()
        playbackTask = nil

        isPreparing = false
        isRunning = false
        beatIndex = 0
        lastBeatDate = nil
        currentPlaybackMidiNote = nil

        Task(priority: .userInitiated) {
            await audio.clearScheduledAudio()
        }
    }

    func selectMode(_ mode: MetronomeMode) {
        guard settings.mode != mode else {
            return
        }

        stop()

        updateSettings { value in
            value.mode = mode
        }
    }

    func setBPM(_ bpm: Double) {
        updateSettings { value in
            value.bpm = bpm
        }

        if isRunning {
            rescheduleActivePlayback()
        }
    }

    func nudgeBPM(_ delta: Int) {
        setBPM(
            settings.bpm + Double(delta)
        )
    }

    func setTimeSignature(
        _ timeSignature: TimeSignature
    ) {
        guard
            settings.timeSignature
                != timeSignature
        else {
            return
        }

        updateSettings { value in
            value.timeSignature =
                timeSignature
        }

        if isRunning {
            rescheduleActivePlayback()
        }
    }

    func setHapticsEnabled(_ enabled: Bool) {
        updateSettings { value in
            value.hapticsEnabled = enabled
        }

        if isRunning {
            rescheduleActivePlayback()
        }
    }

    func setAudioEnabled(_ enabled: Bool) {
        updateSettings { value in
            value.audioEnabled = enabled
        }

        if
            enabled,
            !microphoneOwnsAudioSession
        {
            prepareForUse()
        }

        if isRunning {
            restartPlayback()
        }
    }

    func setBaseMidiNote(
        _ midiNote: Int
    ) {
        let note = min(max(midiNote, 0), 127)

        guard settings.baseMidiNote != note else {
            return
        }

        updateSettings { value in
            value.baseMidiNote = note
        }

        if isRunning {
            rescheduleActivePlayback()
        }
    }

    func nudgeBaseMidiNote(
        _ delta: Int
    ) {
        setBaseMidiNote(
            settings.baseMidiNote + delta
        )
    }

    func setAccentDownbeat(_ enabled: Bool) {
        updateSettings { value in
            value.accentDownbeat = enabled
        }

        if isRunning {
            rescheduleActivePlayback()
        }
    }

    func setClickTone(_ tone: ClickTone) {
        updateSettings { value in
            value.clickTone = tone
        }

        Task {
            await audio.setTone(tone)
        }

        if isRunning {
            rescheduleActivePlayback()
        }
    }

    func previewClick() {
        let tone = settings.clickTone

        Task {
            await audio.preview(
                tone: tone,
                midiNote: settings.baseMidiNote
            )
        }

        if settings.hapticsEnabled,
           WKApplication.shared().applicationState == .active {
            haptics.requestClick()
        }
    }

    func previewHaptic() {
        guard
            settings.hapticsEnabled,
            WKApplication.shared()
                .applicationState == .active
        else {
            return
        }

        haptics.requestClick()
    }

    func setStatusNotificationsEnabled(
        _ enabled: Bool
    ) {
        updateSettings { value in
            value.statusNotificationsEnabled =
                enabled
        }

        if enabled {
            requestNotificationPermission()
        } else {
            clearStatusNotifications()
        }
    }

    // MARK: - Manual rhythm recording

    func beginManualRecording() {
        stop()

        updateSettings { value in
            value.mode = .manual
            value.manualIntervals = []
            value.manualMidiNotes = []
        }

        recordingTapTimes.removeAll(
            keepingCapacity: true
        )

        manualTapCount = 0
        isRecordingManualPattern = true
    }

    func recordManualTap() {
        guard isRecordingManualPattern else {
            return
        }

        let now =
            ProcessInfo.processInfo.systemUptime

        recordingTapTimes.append(now)
        manualTapCount =
            recordingTapTimes.count

        if settings.hapticsEnabled,
           WKApplication.shared().applicationState == .active {
            haptics.requestClick()
        }
    }

    func finishManualRecording() {
        guard isRecordingManualPattern else {
            return
        }

        isRecordingManualPattern = false

        guard recordingTapTimes.count >= 2 else {
            recordingTapTimes.removeAll()
            manualTapCount = 0
            return
        }

        var intervals = zip(
            recordingTapTimes,
            recordingTapTimes.dropFirst()
        )
        .map { previous, next in
            min(
                max(
                    next - previous,
                    MetronomeSettings
                        .minimumManualInterval
                ),
                MetronomeSettings
                    .maximumManualInterval
            )
        }

        let sorted = intervals.sorted()
        let closingInterval =
            sorted[sorted.count / 2]

        intervals.append(closingInterval)

        updateSettings { value in
            value.mode = .manual
            value.manualIntervals =
                intervals
            value.manualMidiNotes =
                Array(
                    repeating: nil,
                    count: intervals.count
                )
        }

        recordingTapTimes.removeAll()
        manualTapCount = 0
    }

    func cancelManualRecording() {
        isRecordingManualPattern = false
        recordingTapTimes.removeAll()
        manualTapCount = 0
    }

    func clearManualPattern() {
        stop()

        updateSettings { value in
            value.manualIntervals = []
            value.manualMidiNotes = []
        }
    }

    // MARK: - Microphone rhythm + tuner

    func beginMicrophoneRecording() {
        guard
            !isPreparingMicrophone,
            !isRecordingMicrophonePattern,
            !isTunerActive
        else {
            return
        }

        stop()

        isPreparingMicrophone = true
        isRecordingMicrophonePattern = true
        microphoneError = nil
        microphoneOnsets.removeAll(
            keepingCapacity: true
        )
        microphoneOnsetCount = 0
        clearDetectedPitch()

        let owner = self

        Task { @MainActor in
            await owner.audio.deactivate()

            // Give watchOS a tiny route/session transition window after
            // playback deactivation before asking for record priority.
            try? await Task.sleep(
                nanoseconds: 60_000_000
            )

            owner.microphone.start(
                onFrame: { frame in
                    Task { @MainActor in
                        owner.handleMicrophoneFrame(
                            frame,
                            recordingPattern: true
                        )
                    }
                },
                completion: { result in
                    Task { @MainActor in
                        owner.isPreparingMicrophone =
                            false

                        if case
                            .failure(let error)
                            = result
                        {
                            owner.isRecordingMicrophonePattern =
                                false
                            owner.microphoneError =
                                error.localizedDescription

                            if owner.settings.audioEnabled {
                                owner.prepareForUse()
                            }
                        }
                    }
                }
            )
        }
    }

    func finishMicrophoneRecording() {
        guard
            isRecordingMicrophonePattern
        else {
            return
        }

        isPreparingMicrophone = false
        isRecordingMicrophonePattern = false

        let owner = self

        microphone.stop {
            Task { @MainActor in
                owner.commitMicrophonePattern()

                if owner.settings.audioEnabled {
                    owner.prepareForUse()
                }
            }
        }
    }

    func cancelMicrophoneRecording() {
        guard
            isRecordingMicrophonePattern
            || isPreparingMicrophone
        else {
            return
        }

        isPreparingMicrophone = false
        isRecordingMicrophonePattern = false
        microphoneOnsets.removeAll()
        microphoneOnsetCount = 0
        clearDetectedPitch()

        let owner = self

        microphone.stop {
            Task { @MainActor in
                if owner.settings.audioEnabled {
                    owner.prepareForUse()
                }
            }
        }
    }

    func beginTuner() {
        guard
            !isPreparingMicrophone,
            !isRecordingMicrophonePattern,
            !isTunerActive
        else {
            return
        }

        stop()

        isPreparingMicrophone = true
        isTunerActive = true
        microphoneError = nil
        clearDetectedPitch()

        let owner = self

        Task { @MainActor in
            await owner.audio.deactivate()

            try? await Task.sleep(
                nanoseconds: 60_000_000
            )

            owner.microphone.start(
                onFrame: { frame in
                    Task { @MainActor in
                        owner.handleMicrophoneFrame(
                            frame,
                            recordingPattern: false
                        )
                    }
                },
                completion: { result in
                    Task { @MainActor in
                        owner.isPreparingMicrophone =
                            false

                        if case
                            .failure(let error)
                            = result
                        {
                            owner.isTunerActive =
                                false
                            owner.microphoneError =
                                error.localizedDescription

                            if owner.settings.audioEnabled {
                                owner.prepareForUse()
                            }
                        }
                    }
                }
            )
        }
    }

    func stopTuner() {
        guard
            isTunerActive
            || isPreparingMicrophone
        else {
            return
        }

        isPreparingMicrophone = false
        isTunerActive = false
        clearDetectedPitch()

        let owner = self

        microphone.stop {
            Task { @MainActor in
                if owner.settings.audioEnabled {
                    owner.prepareForUse()
                }
            }
        }
    }

    private func handleMicrophoneFrame(
        _ frame: MicrophoneFrame,
        recordingPattern: Bool
    ) {
        microphoneLevel =
            min(
                1,
                max(
                    0,
                    frame.rms * 14.0
                )
            )

        if
            frame.confidence >= 0.50,
            let frequency =
                frame.frequency,
            let midiNote =
                frame.midiNote,
            let cents =
                frame.cents
        {
            detectedFrequency =
                frequency
            detectedMidiNote =
                midiNote
            detectedCents =
                cents
        } else if frame.rms < 0.006 {
            detectedFrequency = nil
            detectedMidiNote = nil
            detectedCents = nil
        }

        guard
            recordingPattern,
            frame.onset
        else {
            return
        }

        microphoneOnsets.append(
            (
                timestamp:
                    frame.timestamp,
                midiNote:
                    frame.midiNote
            )
        )

        microphoneOnsetCount =
            microphoneOnsets.count
    }

    private func commitMicrophonePattern() {
        defer {
            microphoneOnsets.removeAll()
            microphoneOnsetCount = 0
            clearDetectedPitch()
        }

        guard
            microphoneOnsets.count >= 2
        else {
            microphoneError =
                "Play or sing at least two clear note attacks."
            return
        }

        var intervals = zip(
            microphoneOnsets,
            microphoneOnsets.dropFirst()
        )
        .map { previous, next in
            min(
                max(
                    next.timestamp
                    - previous.timestamp,
                    MetronomeSettings
                        .minimumManualInterval
                ),
                MetronomeSettings
                    .maximumManualInterval
            )
        }

        let sorted = intervals.sorted()
        let closingInterval =
            sorted[sorted.count / 2]

        intervals.append(
            closingInterval
        )

        let notes =
            microphoneOnsets.map {
                $0.midiNote
            }

        updateSettings { value in
            value.mode = .manual
            value.manualIntervals =
                intervals
            value.manualMidiNotes =
                notes
        }
    }

    private func clearDetectedPitch() {
        detectedFrequency = nil
        detectedMidiNote = nil
        detectedCents = nil
        microphoneLevel = 0
    }

    private static func noteName(
        midiNote: Int
    ) -> String {
        let names = [
            "C", "C♯", "D", "D♯",
            "E", "F", "F♯", "G",
            "G♯", "A", "A♯", "B"
        ]

        let clamped =
            min(max(midiNote, 0), 127)

        let name =
            names[
                clamped % 12
            ]

        let octave =
            clamped / 12 - 1

        return "\(name)\(octave)"
    }

    // MARK: - Scene/background

    func enteredBackground() {
        postStatusNotificationIfNeeded()

        if isRunning,
           !settings.audioEnabled {
            resumeAfterForeground = true
            stop()
        }
    }

    func becameActive() {
        clearStatusNotifications()

        // watchOS 26 can emit additional active/inactive transitions while
        // views and audio routes are changing. Never reconfigure the shared
        // AVAudioSession for playback while microphone recording/tuning owns it.
        guard !microphoneOwnsAudioSession else {
            return
        }

        if settings.audioEnabled {
            prepareForUse()
        }

        if resumeAfterForeground {
            resumeAfterForeground = false
            start()
        }
    }

    // MARK: - Playback

    private func restartPlayback() {
        guard isRunning else {
            return
        }

        stop()
        start()
    }

    private func rescheduleActivePlayback() {
        guard
            isRunning,
            !isPreparing
        else {
            return
        }

        generation &+= 1

        let expectedGeneration =
            generation

        playbackTask?.cancel()
        playbackTask = nil

        let currentSettings =
            settings

        let plan = PlaybackPlan(
            mode:
                currentSettings.mode,
            bpm:
                currentSettings.bpm,
            beatsPerBar:
                currentSettings.beatsPerBar,
            manualIntervals:
                currentSettings.manualIntervals,
            manualMidiNotes:
                currentSettings.manualMidiNotes,
            baseMidiNote:
                currentSettings.baseMidiNote,
            accentDownbeat:
                currentSettings.accentDownbeat,
            audioEnabled:
                currentSettings.audioEnabled,
            hapticsEnabled:
                currentSettings.hapticsEnabled,
            clickTone:
                currentSettings.clickTone
        )

        beatIndex = 0
        lastBeatDate = nil

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.audio
                .clearScheduledAudio()

            guard
                self.isRunning,
                !self.isPreparing,
                self.generation
                    == expectedGeneration
            else {
                return
            }

            let startHostTime =
                mach_absolute_time()
                + AVAudioTime.hostTime(
                    forSeconds: 0.12
                )

            self.beginPlaybackLoop(
                plan: plan,
                generation:
                    expectedGeneration,
                startHostTime:
                    startHostTime
            )
        }
    }

    private func beginPlaybackLoop(
        plan: PlaybackPlan,
        generation expectedGeneration: UInt64,
        startHostTime: UInt64
    ) {
        playbackTask?.cancel()

        let audio = self.audio
        let haptics = self.haptics

        playbackTask = Task.detached(
            priority: .userInitiated
        ) { [weak self] in
            // Core Audio is the renderer, but musical position is the clock.
            //
            // Each event's host time is derived ABSOLUTELY from startHostTime
            // and its musical event index. We never derive beat N+1 from the
            // rounded host time of beat N. That makes this suitable for very
            // long runtime-generated sequences.
            var audioEventIndex = 0
            var liveEventIndex = 0

            let horizonSeconds = 8.0
            let lateToleranceSeconds = 0.050

            while !Task.isCancelled {
                let nowHostTime =
                    mach_absolute_time()

                if plan.audioEnabled {
                    let horizonHostTime =
                        nowHostTime
                        &+ AVAudioTime.hostTime(
                            forSeconds:
                                horizonSeconds
                        )

                    while !Task.isCancelled {
                        let eventHostTime =
                            plan.hostTime(
                                for:
                                    audioEventIndex,
                                startHostTime:
                                    startHostTime
                            )

                        guard
                            eventHostTime
                                <= horizonHostTime
                        else {
                            break
                        }

                        // Never enqueue an audio event which is already
                        // meaningfully in the past. The next event remains
                        // anchored to the original musical timeline.
                        if eventHostTime
                            + AVAudioTime.hostTime(
                                forSeconds: 0.010
                            )
                            >= nowHostTime
                        {
                            await audio
                                .scheduleNote(
                                    accent:
                                        plan.accent(
                                            for:
                                                audioEventIndex
                                        ),
                                    tone:
                                        plan.clickTone,
                                    midiNote:
                                        plan.playbackMidiNote(
                                            for:
                                                audioEventIndex
                                        ),
                                    duration:
                                        plan.noteDuration(
                                            for:
                                                audioEventIndex
                                        ),
                                    hostTime:
                                        eventHostTime
                                )
                        }

                        audioEventIndex += 1
                    }
                }

                let now =
                    mach_absolute_time()

                var liveHostTime =
                    plan.hostTime(
                        for: liveEventIndex,
                        startHostTime:
                            startHostTime
                    )

                if liveHostTime < now {
                    let lateness =
                        AVAudioTime.seconds(
                            forHostTime:
                                now
                                - liveHostTime
                        )

                    if
                        lateness
                            > lateToleranceSeconds
                    {
                        liveEventIndex =
                            plan.firstEventIndex(
                                atOrAfter: now,
                                startHostTime:
                                    startHostTime
                            )

                        liveHostTime =
                            plan.hostTime(
                                for:
                                    liveEventIndex,
                                startHostTime:
                                    startHostTime
                            )
                    }
                }

                let beforeBeat =
                    mach_absolute_time()

                if liveHostTime > beforeBeat {
                    let wait =
                        AVAudioTime.seconds(
                            forHostTime:
                                liveHostTime
                                - beforeBeat
                        )

                    do {
                        try await Task.sleep(
                            nanoseconds:
                                UInt64(
                                    max(
                                        0,
                                        wait
                                    )
                                    * 1_000_000_000
                                )
                        )
                    } catch {
                        break
                    }
                }

                guard
                    !Task.isCancelled
                else {
                    break
                }

                // Re-check against the absolute clock after waking.
                // If the system held this task for too long, skip the
                // old live event instead of firing it late.
                let wakeHostTime =
                    mach_absolute_time()

                if wakeHostTime > liveHostTime {
                    let wakeLateness =
                        AVAudioTime.seconds(
                            forHostTime:
                                wakeHostTime
                                - liveHostTime
                        )

                    if
                        wakeLateness
                            > lateToleranceSeconds
                    {
                        liveEventIndex =
                            plan.firstEventIndex(
                                atOrAfter:
                                    wakeHostTime,
                                startHostTime:
                                    startHostTime
                            )

                        continue
                    }
                }

                if plan.hapticsEnabled {
                    haptics.requestClick()
                }

                let currentStep =
                    plan.step(
                        for: liveEventIndex
                    )

                let recordedNote =
                    plan.recordedMidiNote(
                        for: liveEventIndex
                    )

                await self?.publishBeat(
                    step: currentStep,
                    recordedMidiNote:
                        recordedNote,
                    generation:
                        expectedGeneration
                )

                liveEventIndex += 1
            }
        }
    }

    private func publishBeat(
        step: Int,
        recordedMidiNote: Int?,
        generation expectedGeneration: UInt64
    ) {
        guard
            isRunning,
            generation == expectedGeneration
        else {
            return
        }

        beatIndex = step
        currentPlaybackMidiNote =
            recordedMidiNote
        lastBeatDate = Date()
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert]
            ) { _, _ in
            }
    }

    private func postStatusNotificationIfNeeded() {
        guard
            settings.statusNotificationsEnabled,
            isRunning
        else {
            return
        }

        let content =
            UNMutableNotificationContent()

        switch settings.mode {
        case .bpm:
            content.title =
                "Metronome \(Int(settings.bpm)) BPM"

            content.body =
                settings.timeSignature.label

        case .manual:
            let steps =
                settings.manualIntervals.count

            let approximateBPM =
                manualApproximateBPM
                    .map { " • ~\($0) BPM" }
                ?? ""

            content.title = "Manual rhythm"
            content.body =
                "\(steps) beats\(approximateBPM)"
        }

        let request = UNNotificationRequest(
            identifier:
                "MichiMetronome.CurrentStatus",
            content: content,
            trigger:
                UNTimeIntervalNotificationTrigger(
                    timeInterval: 1,
                    repeats: false
                )
        )

        UNUserNotificationCenter.current()
            .add(request)
    }

    private func clearStatusNotifications() {
        let center =
            UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(
            withIdentifiers: [
                "MichiMetronome.CurrentStatus"
            ]
        )

        center.removeDeliveredNotifications(
            withIdentifiers: [
                "MichiMetronome.CurrentStatus"
            ]
        )
    }

    private func updateSettings(
        _ mutation:
            (inout MetronomeSettings) -> Void
    ) {
        var next = settings

        mutation(&next)
        next.normalize()

        settings = next
        SettingsStore.save(next)
    }
}
