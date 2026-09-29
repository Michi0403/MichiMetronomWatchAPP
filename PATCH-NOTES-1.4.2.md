# MichiMetronome 1.4.2

## Swift compile fix

`PlaybackPlan.step(for:)` had a missing `return` in the `.bpm` switch branch.

Broken:

    case .bpm:
        eventIndex % max(beatsPerBar, 1)

Fixed:

    case .bpm:
        return eventIndex % max(beatsPerBar, 1)

This resolves both compiler diagnostics:

- `Result of operator '%' is unused`
- `Missing return in instance method expected to return 'Int'`

The Xcode project file is preserved byte-for-byte.
