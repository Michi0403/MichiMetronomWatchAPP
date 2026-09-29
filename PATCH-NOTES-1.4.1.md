# MichiMetronome 1.4.1 — synchronized output architecture

This patch is based on 1.4.0. The Xcode project file is preserved byte-for-byte.

## Master clock

Audio is now the master timeline.

`AVAudioPlayerNode` click buffers are scheduled several seconds ahead using
`AVAudioTime(hostTime:)`. This is Core Audio's own monotonic host clock rather
than a SwiftUI/MainActor timer.

The haptic request and visual beat indicator derive from the exact same host-time
sequence.

## Readiness

Start no longer emits a beat while the audio interface is still being activated.

The Start button enters `PREPARING` state. The audio session must finish its
asynchronous watchOS activation before the metronome timeline starts.

If audio activation fails and haptics are enabled, the app may continue
haptic-only and shows an output warning.

## Haptics

WatchKit exposes no public "haptic engine is ready" state and no timestamped
haptic scheduling API. Haptics therefore cannot be made sample-accurate in the
same way as audio.

They are strictly secondary to the audio clock:
- a haptic request never blocks audio scheduling;
- only one haptic request may be in flight;
- a slow/failed haptic startup causes a five-second haptic cooldown;
- missed haptic events are dropped, never queued.

Digital Crown haptic feedback is disabled so crown interaction doesn't compete
with metronome haptics.

## No catch-up bursts

If execution resumes after a stall, every beat already in the past is skipped.
The app never emits missed events rapidly.

Meanwhile Core Audio has several seconds of clicks already scheduled, so an
unrelated WatchKit/CoreHaptics stall should not disturb the audible tempo.

## Xcode project

`MichiMetronomeWatch.xcodeproj/project.pbxproj` was not modified.
