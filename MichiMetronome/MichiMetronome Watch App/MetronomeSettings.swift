import Foundation

enum MetronomeMode: String, Codable, CaseIterable, Sendable {
    case bpm
    case manual

    var title: String {
        switch self {
        case .bpm: "BPM"
        case .manual: "Manual"
        }
    }
}

enum ClickTone: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case wood
    case sharp
    case low
    case beep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wood: "Wood"
        case .sharp: "Sharp"
        case .low: "Low"
        case .beep: "Beep"
        }
    }

    var subtitle: String {
        switch self {
        case .wood: "dry metronome click"
        case .sharp: "short bright tick"
        case .low: "lower wooden tick"
        case .beep: "clean electronic tick"
        }
    }
}

enum TimeSignature: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case twoTwo
    case twoFour
    case threeFour
    case fourFour
    case fiveFour
    case sixFour
    case sevenFour
    case threeEight
    case fiveEight
    case sixEight
    case sevenEight
    case nineEight
    case twelveEight

    var id: String { rawValue }

    var numerator: Int {
        switch self {
        case .twoTwo, .twoFour:
            2
        case .threeFour, .threeEight:
            3
        case .fourFour:
            4
        case .fiveFour, .fiveEight:
            5
        case .sixFour, .sixEight:
            6
        case .sevenFour, .sevenEight:
            7
        case .nineEight:
            9
        case .twelveEight:
            12
        }
    }

    var denominator: Int {
        switch self {
        case .twoTwo:
            2

        case .twoFour,
             .threeFour,
             .fourFour,
             .fiveFour,
             .sixFour,
             .sevenFour:
            4

        case .threeEight,
             .fiveEight,
             .sixEight,
             .sevenEight,
             .nineEight,
             .twelveEight:
            8
        }
    }

    var label: String {
        "\(numerator)/\(denominator)"
    }

    var family: String {
        switch self {
        case .twoTwo:
            "Cut time"
        case .twoFour, .threeFour, .fourFour:
            "Common"
        case .fiveFour, .sixFour, .sevenFour:
            "Asymmetric / extended"
        case .threeEight, .fiveEight, .sixEight, .sevenEight, .nineEight, .twelveEight:
            "Eighth-note meters"
        }
    }

    static func migrated(beatsPerBar: Int) -> TimeSignature {
        switch beatsPerBar {
        case 2: .twoFour
        case 3: .threeFour
        case 5: .fiveFour
        case 6: .sixFour
        case 7: .sevenFour
        case 9: .nineEight
        case 12: .twelveEight
        default: .fourFour
        }
    }
}

struct MetronomeSettings: Codable, Equatable, Sendable {
    static let minimumBPM = 30.0
    static let maximumBPM = 300.0
    static let minimumManualInterval = 0.06
    static let maximumManualInterval = 4.0

    // Safety ceiling only, not a musical limitation.
    // At the minimum 60 ms event spacing this still permits >8 minutes of
    // continuous events; at ordinary musical tempos it permits much longer.
    static let maximumManualEvents = 8_192

    var bpm: Double = 120
    var timeSignature: TimeSignature = .fourFour
    var hapticsEnabled: Bool = true
    var audioEnabled: Bool = true
    var accentDownbeat: Bool = true
    var clickTone: ClickTone = .wood
    var baseMidiNote: Int = 69
    var mode: MetronomeMode = .bpm
    var manualIntervals: [Double] = []

    // One optional MIDI note number per manual beat/event.
    // nil means rhythm-only (for example a finger-tapped pattern).
    var manualMidiNotes: [Int?] = []

    var statusNotificationsEnabled: Bool = false

    var beatsPerBar: Int {
        timeSignature.numerator
    }

    mutating func normalize() {
        bpm = min(
            max(bpm.rounded(), Self.minimumBPM),
            Self.maximumBPM
        )

        baseMidiNote = min(max(baseMidiNote, 0), 127)

        manualIntervals = Array(
            manualIntervals
                .prefix(
                    Self.maximumManualEvents
                )
                .map {
                    min(
                        max(
                            $0,
                            Self.minimumManualInterval
                        ),
                        Self.maximumManualInterval
                    )
                }
        )

        manualMidiNotes = Array(
            manualMidiNotes
                .prefix(manualIntervals.count)
                .map { note in
                    guard let note else {
                        return nil
                    }

                    return min(max(note, 0), 127)
                }
        )

        if manualMidiNotes.count < manualIntervals.count {
            manualMidiNotes.append(
                contentsOf: Array(
                    repeating: nil,
                    count:
                        manualIntervals.count
                        - manualMidiNotes.count
                )
            )
        }
    }
}

enum SettingsStore {
    private static let key = "MichiMetronome.Settings.v6"
    private static let legacyV5Key = "MichiMetronome.Settings.v5"
    private static let legacyV4Key = "MichiMetronome.Settings.v4"
    private static let legacyV3Key = "MichiMetronome.Settings.v3"

    private struct V5Settings: Codable {
        var bpm: Double = 120
        var timeSignature: TimeSignature = .fourFour
        var hapticsEnabled: Bool = true
        var audioEnabled: Bool = true
        var accentDownbeat: Bool = true
        var clickTone: ClickTone = .wood
        var mode: MetronomeMode = .bpm
        var manualIntervals: [Double] = []
        var manualMidiNotes: [Int?] = []
        var statusNotificationsEnabled: Bool = false
    }

    private struct V4Settings: Codable {
        var bpm: Double = 120
        var timeSignature: TimeSignature = .fourFour
        var hapticsEnabled: Bool = true
        var audioEnabled: Bool = true
        var accentDownbeat: Bool = true
        var clickTone: ClickTone = .wood
        var mode: MetronomeMode = .bpm
        var manualIntervals: [Double] = []
        var statusNotificationsEnabled: Bool = false
    }

    private struct V3Settings: Codable {
        var bpm: Double = 120
        var beatsPerBar: Int = 4
        var hapticsEnabled: Bool = true
        var audioEnabled: Bool = true
        var accentDownbeat: Bool = true
        var clickTone: ClickTone = .wood
        var mode: MetronomeMode = .bpm
        var manualIntervals: [Double] = []
        var statusNotificationsEnabled: Bool = false
    }

    static func load() -> MetronomeSettings {
        if
            let data = UserDefaults.standard.data(
                forKey: key
            ),
            var settings = try? JSONDecoder()
                .decode(
                    MetronomeSettings.self,
                    from: data
                )
        {
            settings.normalize()
            return settings
        }

        if
            let data = UserDefaults.standard.data(
                forKey: legacyV5Key
            ),
            let old = try? JSONDecoder().decode(
                V5Settings.self,
                from: data
            )
        {
            var migrated = MetronomeSettings(
                bpm: old.bpm,
                timeSignature: old.timeSignature,
                hapticsEnabled: old.hapticsEnabled,
                audioEnabled: old.audioEnabled,
                accentDownbeat: old.accentDownbeat,
                clickTone: old.clickTone,
                baseMidiNote: 69,
                mode: old.mode,
                manualIntervals: old.manualIntervals,
                manualMidiNotes: old.manualMidiNotes,
                statusNotificationsEnabled:
                    old.statusNotificationsEnabled
            )

            migrated.normalize()
            save(migrated)
            return migrated
        }

        if
            let data = UserDefaults.standard.data(
                forKey: legacyV4Key
            ),
            let old = try? JSONDecoder().decode(
                V4Settings.self,
                from: data
            )
        {
            var migrated = MetronomeSettings(
                bpm: old.bpm,
                timeSignature: old.timeSignature,
                hapticsEnabled: old.hapticsEnabled,
                audioEnabled: old.audioEnabled,
                accentDownbeat: old.accentDownbeat,
                clickTone: old.clickTone,
                baseMidiNote: 69,
                mode: old.mode,
                manualIntervals: old.manualIntervals,
                manualMidiNotes: Array(
                    repeating: nil,
                    count: old.manualIntervals.count
                ),
                statusNotificationsEnabled:
                    old.statusNotificationsEnabled
            )

            migrated.normalize()
            save(migrated)
            return migrated
        }

        if
            let data = UserDefaults.standard.data(
                forKey: legacyV3Key
            ),
            let old = try? JSONDecoder().decode(
                V3Settings.self,
                from: data
            )
        {
            var migrated = MetronomeSettings(
                bpm: old.bpm,
                timeSignature:
                    .migrated(
                        beatsPerBar:
                            old.beatsPerBar
                    ),
                hapticsEnabled:
                    old.hapticsEnabled,
                audioEnabled:
                    old.audioEnabled,
                accentDownbeat:
                    old.accentDownbeat,
                clickTone:
                    old.clickTone,
                mode:
                    old.mode,
                manualIntervals:
                    old.manualIntervals,
                manualMidiNotes: Array(
                    repeating: nil,
                    count:
                        old.manualIntervals.count
                ),
                statusNotificationsEnabled:
                    old.statusNotificationsEnabled
            )

            migrated.normalize()
            save(migrated)
            return migrated
        }

        return MetronomeSettings()
    }

    static func save(
        _ settings: MetronomeSettings
    ) {
        var normalized = settings
        normalized.normalize()

        guard
            let data = try? JSONEncoder()
                .encode(normalized)
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }
}
