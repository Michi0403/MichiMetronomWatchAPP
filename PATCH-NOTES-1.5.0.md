# MichiMetronome 1.5.0

Based on 1.4.2. The Xcode project file is preserved byte-for-byte.

## Time signatures

The old "tap 4/4 to cycle numerator only" behavior is removed.

The app now has a dedicated meter picker with:

- 2/2
- 2/4
- 3/4
- 4/4
- 5/4
- 6/4
- 7/4
- 3/8
- 5/8
- 6/8
- 7/8
- 9/8
- 12/8

The main beat-marker strip uses the numerator, so the number of dots follows
the selected bar automatically. Large meters use smaller dots to fit the SE.

Existing v3 settings are migrated once into v4 settings.

## Tempo controls

Both the main BPM screen and the dedicated Crown tempo editor now have:

- -5
- -1
- +1
- +5

Changing BPM, time signature, haptic toggle, accent, or click tone while already
running reschedules the active Core Audio timeline directly. It does NOT call the
full Start/Prepare path, so the PREPARING state should no longer flash when using
the tempo buttons.

## Start/Stop control

The Start/Stop button now uses a fixed-height custom SwiftUI button rather than
`borderedProminent`. Its label does not grow to "Preparing"; preparation is shown
only in the small status header.

UI state is still cleared synchronously on Stop, while the Core Audio scheduled
buffer flush is requested at user-initiated priority.

The `CoreUI: CUIThemeStore: No theme registered with id=0` message is emitted by
Apple's UI framework. This revision avoids the prominent themed style on the
Start/Stop control to reduce that path, but the log itself is not an application
audio/timing error.

## Haptic strength

No fake strength slider was added.

`WKInterfaceDevice.play(.click)` exposes a predefined WatchKit haptic type, not a
numeric intensity parameter. Triggering multiple clicks to simulate "stronger"
feedback would directly contradict Apple's guidance to avoid rapid repeated haptic
calls and would reintroduce the timing/startup problems already observed on the
physical Watch.

Settings now has a Test Haptic button and explains that strength is controlled by
watchOS.
