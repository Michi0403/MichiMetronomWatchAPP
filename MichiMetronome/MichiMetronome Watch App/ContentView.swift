import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: MetronomeEngine
    @State private var showSettings = false
    @State private var showTempoEditor = false
    @State private var showMeterPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 7) {
                header
                modePicker

                if engine.settings.mode == .bpm {
                    BPMPanel(
                        showTempoEditor:
                            $showTempoEditor
                    )
                } else {
                    ManualPanel()
                }

                playbackButton
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .task {
            engine.prepareForUse()
        }
        .sheet(
            isPresented: $showSettings
        ) {
            SettingsView()
                .environmentObject(engine)
        }
        .sheet(
            isPresented: $showTempoEditor
        ) {
            TempoCrownView()
                .environmentObject(engine)
        }
        .sheet(
            isPresented: $showMeterPicker
        ) {
            MeterPickerView()
                .environmentObject(engine)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(
                    engine.isRunning
                    ? Color.green
                    : Color.secondary.opacity(0.5)
                )
                .frame(width: 6, height: 6)

            Text(
                engine.isPreparing
                ? "PREPARING"
                : (engine.isRunning ? "RUNNING" : "READY")
            )
            .font(
                .system(
                    size: 10,
                    weight: .bold
                )
            )
            .foregroundStyle(
                engine.isRunning
                ? .green
                : .secondary
            )

            Spacer()

            if engine.settings.mode == .bpm {
                Button {
                    showMeterPicker = true
                } label: {
                    HStack(spacing: 3) {
                        Text(
                            engine.settings
                                .timeSignature.label
                        )
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold
                            )
                            .monospacedDigit()
                        )

                        Image(
                            systemName:
                                "chevron.down"
                        )
                        .font(
                            .system(
                                size: 8,
                                weight: .bold
                            )
                        )
                    }
                    .frame(
                        minWidth: 58,
                        minHeight: 44
                    )
                    .contentShape(
                        .interaction,
                        RoundedRectangle(
                            cornerRadius: 12
                        )
                    )
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                    .fill(
                        Color.white
                            .opacity(0.08)
                    )
                )
                .accessibilityLabel(
                    "Time signature, \(engine.settings.timeSignature.label)"
                )
                .accessibilityHint(
                    "Opens the meter selector"
                )
            }

            Button {
                showSettings = true
            } label: {
                Image(
                    systemName: "gearshape.fill"
                )
                .font(.system(size: 15))
                .frame(
                    width: 44,
                    height: 44
                )
                .contentShape(
                    .interaction,
                    Rectangle()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var modePicker: some View {
        HStack(spacing: 5) {
            modeButton(.bpm)
            modeButton(.manual)
        }
    }

    private func modeButton(
        _ mode: MetronomeMode
    ) -> some View {
        Button {
            engine.selectMode(mode)
        } label: {
            Text(mode.title)
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(
            engine.settings.mode == mode
            ? .green
            : .gray
        )
        .frame(
            maxWidth: .infinity,
            minHeight: 42
        )
        .contentShape(
            .interaction,
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }

    private var playbackButton: some View {
        Button {
            engine.toggle()
        } label: {
            HStack(spacing: 6) {
                if engine.isPreparing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(
                        systemName:
                            engine.isRunning
                            ? "stop.fill"
                            : "play.fill"
                    )
                }

                Text(
                    engine.isRunning
                    ? "Stop"
                    : "Start"
                )
            }
            .font(
                .system(
                    size: 16,
                    weight: .bold
                )
            )
            .frame(
                maxWidth: .infinity,
                minHeight: 38,
                maxHeight: 38
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 14
                )
            )
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                engine.isRunning
                ? Color.red
                : Color.green
            )
        )
        .foregroundStyle(.black)
        .opacity(
            engine.isPreparing
            ? 0.75
            : 1
        )
        .disabled(
            engine.isPreparing
            || (
                !engine.isRunning
                && !engine.canStart
            )
        )
    }
}

private struct BPMPanel: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    @Binding var showTempoEditor: Bool

    var body: some View {
        VStack(spacing: 6) {
            Button {
                showTempoEditor = true
            } label: {
                VStack(spacing: -1) {
                    Text(
                        "\(Int(engine.settings.bpm))"
                    )
                    .font(
                        .system(
                            size: 34,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()

                    Text(
                        "BPM • \(engine.baseNoteName) • tap for crown"
                    )
                        .font(
                            .system(
                                size: 9,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.green)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: 56
                )
                .padding(.vertical, 4)
                .contentShape(
                    .interaction,
                    RoundedRectangle(
                        cornerRadius: 14
                    )
                )
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    Color.white.opacity(0.06)
                )
            )

            BPMBeatStrip()

            TempoStepGrid()
        }
    }
}



private struct TempoStepGrid: View {
    private let columns = [
        GridItem(
            .flexible(),
            spacing: 6
        ),
        GridItem(
            .flexible(),
            spacing: 6
        )
    ]

    var body: some View {
        LazyVGrid(
            columns: columns,
            spacing: 6
        ) {
            // Negative is always left, positive always right.
            // Matching step sizes stay on the same row.
            TempoStepButton(
                title: "-5",
                delta: -5
            )
            TempoStepButton(
                title: "+5",
                delta: 5
            )
            TempoStepButton(
                title: "-1",
                delta: -1
            )
            TempoStepButton(
                title: "+1",
                delta: 1
            )
        }
    }
}

private struct TempoStepButton: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    let title: String
    let delta: Int

    var body: some View {
        Button {
            engine.nudgeBPM(delta)
        } label: {
            Text(title)
                .font(
                    .system(
                        size: 15,
                        weight: .bold
                    )
                    .monospacedDigit()
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
                .contentShape(
                    .interaction,
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                )
        }
        .buttonStyle(.bordered)
    }
}

private struct TempoCrownView: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    @Environment(\.dismiss)
    private var dismiss

    @State private var crownBPM = 120.0

    var body: some View {
        VStack(spacing: 9) {
            Text("Tempo")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: -2) {
                Text(
                    "\(Int(engine.settings.bpm))"
                )
                .font(
                    .system(
                        size: 48,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .monospacedDigit()

                Text("BPM • turn crown")
                    .font(
                        .caption2.weight(.semibold)
                    )
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity)
            .focusable()
            .digitalCrownRotation(
                $crownBPM,
                from:
                    MetronomeSettings.minimumBPM,
                through:
                    MetronomeSettings.maximumBPM,
                by: 1,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onChange(
                of: crownBPM
            ) { _, value in
                engine.setBPM(value)
            }
            .onChange(
                of: engine.settings.bpm
            ) { _, value in
                if crownBPM != value {
                    crownBPM = value
                }
            }
            .onAppear {
                crownBPM =
                    engine.settings.bpm
            }

            TempoStepGrid()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 8)
    }
}

private struct BPMBeatStrip: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    private var compact: Bool {
        engine.settings.beatsPerBar > 8
    }

    var body: some View {
        HStack(
            spacing: compact ? 2 : 3
        ) {
            ForEach(
                0..<engine.settings
                    .beatsPerBar,
                id: \.self
            ) { beat in
                Circle()
                    .fill(
                        active(beat)
                        ? Color.green
                        : Color.secondary
                            .opacity(0.28)
                    )
                    .frame(
                        width:
                            active(beat)
                            ? (compact ? 6 : 8)
                            : (compact ? 4 : 5),
                        height:
                            active(beat)
                            ? (compact ? 6 : 8)
                            : (compact ? 4 : 5)
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 10
        )
    }

    private func active(
        _ beat: Int
    ) -> Bool {
        guard engine.isRunning else {
            return false
        }

        return beat == engine.beatIndex
    }
}


private struct MeterPickerView: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Common") {
                    meterRow(.twoTwo)
                    meterRow(.twoFour)
                    meterRow(.threeFour)
                    meterRow(.fourFour)
                }

                Section("Odd / extended") {
                    meterRow(.fiveFour)
                    meterRow(.sixFour)
                    meterRow(.sevenFour)
                }

                Section("Eighth-note meters") {
                    meterRow(.threeEight)
                    meterRow(.fiveEight)
                    meterRow(.sixEight)
                    meterRow(.sevenEight)
                    meterRow(.nineEight)
                    meterRow(.twelveEight)
                }
            }
            .navigationTitle("Meter")
        }
    }

    @ViewBuilder
    private func meterRow(
        _ meter: TimeSignature
    ) -> some View {
        Button {
            engine.setTimeSignature(meter)
            dismiss()
        } label: {
            HStack {
                Text(meter.label)
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                        .monospacedDigit()
                    )

                Spacer()

                if
                    engine.settings
                        .timeSignature == meter
                {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
            }
            .frame(minHeight: 44)
            .contentShape(
                .interaction,
                Rectangle()
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ManualPanel: View {
    @EnvironmentObject private var engine: MetronomeEngine

    var body: some View {
        VStack(spacing: 8) {
            if engine.isRecordingMicrophonePattern {
                microphoneRecordingView
            } else if engine.isRecordingManualPattern {
                recordingView
            } else if engine.settings.manualIntervals.isEmpty {
                emptyView
            } else {
                patternView
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(.green)

            Text("Record your rhythm")
                .font(.headline)

            Text("Tap the beat naturally. The exact gaps are looped, so it can be irregular.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button {
                    engine.beginManualRecording()
                } label: {
                    Label(
                        "Tap",
                        systemImage:
                            "hand.tap.fill"
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 44
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(.green)

                Button {
                    engine
                        .beginMicrophoneRecording()
                } label: {
                    Label(
                        "Mic",
                        systemImage:
                            "mic.fill"
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 44
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(.blue)
            }

            if let error =
                engine.microphoneError
            {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(
                        .center
                    )
            }
        }
        .padding(.vertical, 8)
    }

    private var recordingView: some View {
        VStack(spacing: 8) {
            Text("\(engine.manualTapCount) taps")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                engine.recordManualTap()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title2)
                    Text("TAP")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 62)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            HStack(spacing: 6) {
                Button("Cancel") {
                    engine.cancelManualRecording()
                }
                .buttonStyle(.bordered)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )

                Button("Use") {
                    engine.finishManualRecording()
                }
                .buttonStyle(.borderedProminent)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
                .disabled(engine.manualTapCount < 2)
            }
        }
    }

    private var microphoneRecordingView: some View {
        VStack(spacing: 7) {
            HStack {
                Image(
                    systemName:
                        "mic.fill"
                )
                .foregroundStyle(.blue)

                Text(
                    engine.isPreparingMicrophone
                    ? "Starting microphone…"
                    : "\(engine.microphoneOnsetCount) notes"
                )
                .font(
                    .caption
                    .monospacedDigit()
                )

                Spacer()
            }

            VStack(spacing: 1) {
                Text(
                    engine.detectedNoteName
                    ?? "—"
                )
                .font(
                    .system(
                        size: 34,
                        weight: .bold,
                        design: .rounded
                    )
                )

                if
                    let frequency =
                        engine.detectedFrequency,
                    let cents =
                        engine.detectedCents
                {
                    Text(
                        String(
                            format:
                                "%.1f Hz  •  %+.0f¢",
                            frequency,
                            cents
                        )
                    )
                    .font(
                        .caption2
                        .monospacedDigit()
                    )
                    .foregroundStyle(
                        abs(cents) <= 5
                        ? .green
                        : .secondary
                    )
                } else {
                    Text(
                        "Play or sing clear notes"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 58
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    Color.white
                        .opacity(0.06)
                )
            )

            ProgressView(
                value:
                    engine.microphoneLevel,
                total: 1
            )

            HStack(spacing: 6) {
                Button("Cancel") {
                    engine
                        .cancelMicrophoneRecording()
                }
                .buttonStyle(.bordered)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )

                Button("Use") {
                    engine
                        .finishMicrophoneRecording()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(.blue)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
                .disabled(
                    engine.microphoneOnsetCount
                        < 2
                    || engine
                        .isPreparingMicrophone
                )
            }
        }
    }

    private var patternView: some View {
        VStack(spacing: 6) {
            PatternTimelineView()

            HStack {
                Text("\(engine.settings.manualIntervals.count) beats")
                    .font(.caption2.monospacedDigit())

                Spacer()

                if let bpm = engine.manualApproximateBPM {
                    Text("~\(bpm) BPM")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if
                engine.isRunning,
                let note =
                    engine.currentPlaybackNoteName
            {
                HStack(spacing: 5) {
                    Image(
                        systemName:
                            "speaker.wave.2.fill"
                    )
                    .foregroundStyle(.blue)

                    Text(note)
                        .font(
                            .system(
                                size: 22,
                                weight: .bold,
                                design: .rounded
                            )
                            .monospaced()
                        )

                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }

            if
                let notes =
                    engine.manualNoteSummary
            {
                Text(notes)
                    .font(
                        .caption2
                        .monospaced()
                    )
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }

            HStack(spacing: 6) {
                Button {
                    engine.beginManualRecording()
                } label: {
                    Label(
                        "Tap",
                        systemImage:
                            "hand.tap.fill"
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 44
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    engine
                        .beginMicrophoneRecording()
                } label: {
                    Label(
                        "Mic",
                        systemImage:
                            "mic.fill"
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 44
                    )
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            Button {
                engine.clearManualPattern()
            } label: {
                Label(
                    "Clear pattern",
                    systemImage: "trash"
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 40
                )
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

private struct PatternTimelineView: View {
    @EnvironmentObject private var engine: MetronomeEngine

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(height: 3)
                        .offset(y: 12)

                    ForEach(
                        Array(engine.manualBeatPositions.enumerated()),
                        id: \.offset
                    ) { index, position in
                        Circle()
                            .fill(
                                isCurrent(index)
                                ? Color.green
                                : Color.white.opacity(0.72)
                            )
                            .frame(
                                width: isCurrent(index) ? 10 : 7,
                                height: isCurrent(index) ? 10 : 7
                            )
                            .offset(
                                x: max(
                                    0,
                                    geometry.size.width * position - 4
                                ),
                                y: 8
                            )
                    }

                    if engine.isRunning {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 2, height: 26)
                            .offset(
                                x: geometry.size.width
                                    * engine.manualProgress(at: context.date)
                            )
                    }
                }
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func isCurrent(_ index: Int) -> Bool {
        engine.isRunning && engine.beatIndex == index
    }
}



private struct SettingsView: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    @Environment(\.dismiss)
    private var dismiss

    @State private var showTuner = false
    @State private var showBaseNote = false

    var body: some View {
        NavigationStack {
            List {
                Section("Output") {
                    Toggle(
                        "Haptics",
                        isOn: Binding(
                            get: {
                                engine.settings
                                    .hapticsEnabled
                            },
                            set: {
                                engine
                                    .setHapticsEnabled($0)
                            }
                        )
                    )

                    Button {
                        engine.previewHaptic()
                    } label: {
                        Label(
                            "Test haptic",
                            systemImage:
                                "waveform.path"
                        )
                    }

                    Text(
                        "Haptic strength is controlled by watchOS. WatchKit's metronome-safe click API exposes the haptic type, but no app-level intensity value."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Toggle(
                        "Sound",
                        isOn: Binding(
                            get: {
                                engine.settings
                                    .audioEnabled
                            },
                            set: {
                                engine
                                    .setAudioEnabled($0)
                            }
                        )
                    )

                    Picker(
                        "Click tone",
                        selection: Binding(
                            get: {
                                engine.settings
                                    .clickTone
                            },
                            set: {
                                engine
                                    .setClickTone($0)
                            }
                        )
                    ) {
                        ForEach(
                            ClickTone.allCases
                        ) { tone in
                            Text(tone.title)
                                .tag(tone)
                        }
                    }

                    Button {
                        showBaseNote = true
                    } label: {
                        HStack {
                            Label(
                                "Base note",
                                systemImage:
                                    "music.note"
                            )

                            Spacer()

                            Text(
                                engine.baseNoteName
                            )
                            .font(
                                .body
                                .monospaced()
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }

                    Button {
                        engine.previewClick()
                    } label: {
                        Label(
                            "Preview click",
                            systemImage:
                                "speaker.wave.2.fill"
                        )
                    }

                    Toggle(
                        "Accent first beat",
                        isOn: Binding(
                            get: {
                                engine.settings
                                    .accentDownbeat
                            },
                            set: {
                                engine
                                    .setAccentDownbeat($0)
                            }
                        )
                    )

                    Text(
                        "Haptic clicks are isolated from the UI. If watchOS takes too long starting the Taptic Engine, that haptic is dropped instead of freezing or delaying the metronome."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Section("Tools") {
                    Button {
                        showTuner = true
                    } label: {
                        Label(
                            "Instrument Tuner",
                            systemImage:
                                "tuningfork"
                        )
                    }

                    Text(
                        "The tuner and Mic rhythm recorder analyze the Watch microphone locally. Raw audio is not saved or uploaded."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if let warning = engine.outputWarning {
                    Section("Output status") {
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Status") {
                    Toggle(
                        "Notify when leaving",
                        isOn: Binding(
                            get: {
                                engine.settings
                                    .statusNotificationsEnabled
                            },
                            set: {
                                engine
                                    .setStatusNotificationsEnabled(
                                        $0
                                    )
                            }
                        )
                    )
                }

                Section("Background") {
                    Text(
                        "Sound can continue in the background. Ordinary WatchKit haptics are only available while the app is active."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Section("Offline") {
                    Text(
                        "No network, account, cloud sync, or phone app."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(
            isPresented: $showTuner
        ) {
            TunerView()
                .environmentObject(engine)
        }
        .sheet(
            isPresented: $showBaseNote
        ) {
            BaseNoteView()
                .environmentObject(engine)
        }
    }
}


private struct TunerView: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Instrument Tuner")
                    .font(.headline)

                VStack(spacing: 1) {
                    Text(
                        engine.detectedNoteName
                        ?? "—"
                    )
                    .font(
                        .system(
                            size: 46,
                            weight: .bold,
                            design: .rounded
                        )
                    )

                    if
                        let frequency =
                            engine.detectedFrequency,
                        let cents =
                            engine.detectedCents
                    {
                        Text(
                            String(
                                format:
                                    "%.1f Hz",
                                frequency
                            )
                        )
                        .font(
                            .caption
                            .monospacedDigit()
                        )

                        Text(
                            String(
                                format:
                                    "%+.0f cents",
                                cents
                            )
                        )
                        .font(
                            .caption
                            .monospacedDigit()
                        )
                        .foregroundStyle(
                            abs(cents) <= 5
                            ? .green
                            : .orange
                        )
                    } else {
                        Text(
                            "Play a steady note"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: 86
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                    .fill(
                        Color.white
                            .opacity(0.06)
                    )
                )

                ProgressView(
                    value:
                        engine.microphoneLevel,
                    total: 1
                )

                if let error =
                    engine.microphoneError
                {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(
                            .center
                        )
                }

                Button {
                    if
                        engine.isTunerActive
                        || engine
                            .isPreparingMicrophone
                    {
                        engine.stopTuner()
                    } else {
                        engine.beginTuner()
                    }
                } label: {
                    HStack {
                        if
                            engine
                                .isPreparingMicrophone
                        {
                            ProgressView()
                                .controlSize(.mini)
                        }

                        Text(
                            engine.isTunerActive
                            || engine
                                .isPreparingMicrophone
                            ? "Stop"
                            : "Start Tuner"
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 44
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(
                    engine.isTunerActive
                    || engine
                        .isPreparingMicrophone
                    ? .red
                    : .blue
                )

                Button("Done") {
                    if
                        engine.isTunerActive
                        || engine
                            .isPreparingMicrophone
                    {
                        engine.stopTuner()
                    }

                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 6)
        }
        .onDisappear {
            if
                engine.isTunerActive
                || engine
                    .isPreparingMicrophone
            {
                engine.stopTuner()
            }
        }
    }
}


private struct BaseNoteView: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    @Environment(\.dismiss)
    private var dismiss

    @State private var crownNote = 69.0

    var body: some View {
        VStack(spacing: 8) {
            Text("Base Note")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: -2) {
                Text(engine.baseNoteName)
                    .font(
                        .system(
                            size: 46,
                            weight: .bold,
                            design: .rounded
                        )
                        .monospaced()
                    )

                Text(
                    "MIDI \(engine.settings.baseMidiNote)"
                )
                .font(
                    .caption2
                    .monospacedDigit()
                )
                .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 68
            )
            .focusable()
            .digitalCrownRotation(
                $crownNote,
                from: 24,
                through: 96,
                by: 1,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onChange(
                of: crownNote
            ) { _, value in
                engine.setBaseMidiNote(
                    Int(value.rounded())
                )
            }
            .onChange(
                of:
                    engine.settings.baseMidiNote
            ) { _, value in
                if Int(crownNote.rounded()) != value {
                    crownNote = Double(value)
                }
            }
            .onAppear {
                crownNote =
                    Double(
                        engine.settings
                            .baseMidiNote
                    )
            }

            HStack(spacing: 4) {
                BaseNoteStepButton(
                    title: "-12",
                    delta: -12
                )
                BaseNoteStepButton(
                    title: "+12",
                    delta: 12
                )
            }

            HStack(spacing: 4) {
                BaseNoteStepButton(
                    title: "-1",
                    delta: -1
                )
                BaseNoteStepButton(
                    title: "+1",
                    delta: 1
                )
            }

            HStack(spacing: 5) {
                Button {
                    engine.previewClick()
                } label: {
                    Label(
                        "Hear",
                        systemImage:
                            "speaker.wave.2.fill"
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 40
                    )
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 40
                )
            }
        }
        .padding(.horizontal, 7)
    }
}

private struct BaseNoteStepButton: View {
    @EnvironmentObject private var engine:
        MetronomeEngine

    let title: String
    let delta: Int

    var body: some View {
        Button(title) {
            engine.nudgeBaseMidiNote(delta)
        }
        .font(
            .system(
                size: 13,
                weight: .semibold
            )
            .monospacedDigit()
        )
        .buttonStyle(.bordered)
        .frame(
            maxWidth: .infinity,
            minHeight: 40
        )
    }
}
