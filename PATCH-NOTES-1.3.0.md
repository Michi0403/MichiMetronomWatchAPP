# MichiMetronome 1.3.0 source patch

This revision is based directly on the uploaded `metronom.zip`.

## Important: Xcode project preserved

`MichiMetronomeWatch.xcodeproj/project.pbxproj` is copied byte-for-byte from the
uploaded project. This patch does not regenerate or "upgrade" the Xcode project.

## Start/debugger crash

The prototype created a new `DispatchSourceTimer` for every beat and replaced the
last timer while its handler was executing. That entire scheduler has been
removed.

Playback now uses one cancellable Swift concurrency Task. Timing is corrected
against `systemUptime`, so small per-beat execution overhead does not accumulate
into permanent tempo drift.

This also removes the custom metronome scheduler queue from the crash path.

## Digital Crown

The BPM crown control is no longer inside the main ScrollView and no longer
forces an explicit `@FocusState`. It follows the simpler Apple pattern:

`focusable()` + `digitalCrownRotation(...)`.

## Haptic

The downbeat no longer uses `WKHapticType.notification`.

Every beat uses the short `.click` haptic. The downbeat accent is audio-only.
WatchKit does not expose an arbitrary haptic-strength parameter for this API.

## Sound

The AVAudioEngine prototype was replaced with simple prepared AVAudioPlayer
instances backed by generated WAV data.

Selectable local tones:
- Wood
- Sharp
- Low
- Beep

No sound files are downloaded or required.

A Preview Click button is available in Settings.
