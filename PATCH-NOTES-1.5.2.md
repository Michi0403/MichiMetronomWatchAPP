# MichiMetronome 1.5.2

## watchOS build fix

`PickerStyle.menu` is unavailable on watchOS in the Xcode 26.6 SDK.

The unsupported menu-style Picker has been removed.

The main screen now shows a large dropdown-like meter control such as:

    4/4 ▾

Tapping it opens a native watchOS sheet containing a scrollable List of meters.
Every row has a minimum 44 pt touch height and the current meter is marked.

The list is grouped into:
- Common
- Odd / extended
- Eighth-note meters

This preserves the requested dropdown/list behavior without using an unavailable
watchOS Picker style.

## AVAudioPlayerNode warning

Xcode's "Consider using asynchronous alternative function" diagnostic on the
preview-click `scheduleBuffer` call is a warning, not the compilation error.

The exact-host-time metronome scheduling path is intentionally explicit and is
unchanged in this revision.

The Xcode project file is preserved byte-for-byte.
