import AVFoundation
import Foundation

actor ClickAudioEngine {
    private struct BufferKey: Hashable {
        let tone: ClickTone
        let midiNote: Int
        let accent: Bool
        let frameCount: Int
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private let sourceFormat = AVAudioFormat(
        standardFormatWithSampleRate: 44_100,
        channels: 1
    )!

    private var connected = false
    private var prepared = false
    private var preparing = false
    private var bufferCache: [BufferKey: AVAudioPCMBuffer] = [:]

    init() {
        engine.attach(player)
    }

    var isReady: Bool {
        prepared && engine.isRunning
    }

    func prepareSession(tone: ClickTone) async -> Bool {
        _ = tone

        if prepared {
            if !engine.isRunning {
                do {
                    try engine.start()
                } catch {
                    prepared = false
                    return false
                }
            }

            if !player.isPlaying {
                player.play()
            }

            return true
        }

        if preparing {
            while preparing {
                try? await Task.sleep(
                    nanoseconds: 10_000_000
                )
            }

            return prepared
        }

        preparing = true
        defer { preparing = false }

        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )

            _ = try await session.activate()

            if !connected {
                engine.connect(
                    player,
                    to: engine.mainMixerNode,
                    format: sourceFormat
                )
                connected = true
            }

            engine.prepare()
            try engine.start()
            player.play()

            prepared = true
            return true
        } catch {
            prepared = false
            return false
        }
    }

    func setTone(_ tone: ClickTone) {
        _ = tone
    }

    func scheduleNote(
        accent: Bool,
        tone: ClickTone,
        midiNote: Int,
        duration: TimeInterval,
        hostTime: UInt64
    ) {
        guard prepared, engine.isRunning else {
            return
        }

        let note = min(max(midiNote, 0), 127)
        let noteDuration = min(max(duration, 0.045), 0.45)
        let frameCount = max(
            1,
            Int(sourceFormat.sampleRate * noteDuration)
        )

        let key = BufferKey(
            tone: tone,
            midiNote: note,
            accent: accent,
            frameCount: frameCount
        )

        let buffer: AVAudioPCMBuffer

        if let cached = bufferCache[key] {
            buffer = cached
        } else {
            guard
                let generated = Self.makeNoteBuffer(
                    format: sourceFormat,
                    tone: tone,
                    midiNote: note,
                    accent: accent,
                    frameCount: frameCount
                )
            else {
                return
            }

            if bufferCache.count >= 192 {
                bufferCache.removeAll(
                    keepingCapacity: true
                )
            }

            bufferCache[key] = generated
            buffer = generated
        }

        if !player.isPlaying {
            player.play()
        }

        player.scheduleBuffer(
            buffer,
            at: AVAudioTime(hostTime: hostTime),
            options: [],
            completionHandler: nil
        )
    }

    func preview(
        tone: ClickTone,
        midiNote: Int
    ) async {
        guard await prepareSession(tone: tone) else {
            return
        }

        let note = min(max(midiNote, 0), 127)
        let frameCount = Int(
            sourceFormat.sampleRate * 0.18
        )

        let key = BufferKey(
            tone: tone,
            midiNote: note,
            accent: false,
            frameCount: frameCount
        )

        let buffer: AVAudioPCMBuffer

        if let cached = bufferCache[key] {
            buffer = cached
        } else {
            guard
                let generated = Self.makeNoteBuffer(
                    format: sourceFormat,
                    tone: tone,
                    midiNote: note,
                    accent: false,
                    frameCount: frameCount
                )
            else {
                return
            }

            bufferCache[key] = generated
            buffer = generated
        }

        player.scheduleBuffer(
            buffer,
            at: nil,
            options: [],
            completionHandler: nil
        )
    }

    func clearScheduledAudio() {
        player.stop()

        if prepared, engine.isRunning {
            player.play()
        }
    }

    func suspend() {
        player.stop()

        if engine.isRunning {
            engine.pause()
        }
    }

    func deactivate() {
        player.stop()
        engine.stop()
        prepared = false

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }

    private static func makeNoteBuffer(
        format: AVAudioFormat,
        tone: ClickTone,
        midiNote: Int,
        accent: Bool,
        frameCount: Int
    ) -> AVAudioPCMBuffer? {
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
            ),
            let channel = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        let frequency =
            440.0
            * pow(
                2.0,
                Double(midiNote - 69) / 12.0
            )

        let amplitude = accent ? 0.80 : 0.63
        let attackSeconds = 0.004

        for frame in 0..<frameCount {
            let time =
                Double(frame) / format.sampleRate

            let normalized =
                Double(frame)
                / Double(max(frameCount - 1, 1))

            let attack =
                min(1.0, time / attackSeconds)

            let releasePower =
                tone == .beep ? 1.5 : 2.8

            let release =
                pow(
                    max(0, 1.0 - normalized),
                    releasePower
                )

            let envelope = attack * release

            let phase =
                2.0
                * Double.pi
                * frequency
                * time

            let harmonicSample: Double

            switch tone {
            case .wood:
                harmonicSample =
                    sin(phase) * 0.74
                    + sin(phase * 2.01) * 0.18
                    + sin(phase * 3.97) * 0.08

            case .sharp:
                harmonicSample =
                    sin(phase) * 0.55
                    + sin(phase * 2.0) * 0.28
                    + sin(phase * 4.0) * 0.17

            case .low:
                harmonicSample =
                    sin(phase) * 0.84
                    + sin(phase * 2.0) * 0.16

            case .beep:
                harmonicSample = sin(phase)
            }

            let transient: Double

            if frame < 10 {
                transient =
                    frame.isMultiple(of: 2)
                    ? 0.12
                    : -0.12
            } else {
                transient = 0
            }

            let sample =
                (
                    harmonicSample * envelope
                    + transient * release
                )
                * amplitude

            channel[frame] =
                Float(max(-1, min(1, sample)))
        }

        return buffer
    }
}
