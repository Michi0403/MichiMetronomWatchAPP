# MichiMetronome 1.8.2 — Watch audio-session + fast melody capture fix

## Fast note changes

Mic analysis now uses 1024-frame buffers and approximately 20 ms analysis cadence.

The onset detector no longer compares a new pitch only to the immediately
previous tuner frame. It compares against the last note that was actually
recorded as an onset. Therefore a fast note change that happens inside the short
refractory window remains pending and is recorded as soon as the detector can
legitimately emit the next onset.

Minimum onset spacing is now 65 ms instead of 120 ms.

## Repeat microphone/tuner use

The playback -> microphone -> playback handoff now uses the asynchronous watchOS
AVAudioSession activation/deactivation APIs.

The app waits for playback deactivation before requesting microphone priority,
and microphone completion waits for actual session deactivation before preparing
playback again. This addresses the `SessionCore ... '!pri'` priority race seen
after the first microphone recording.

## Swift concurrency

The Xcode 26.6 Watch template defaults ordinary declarations to MainActor.
Background helper types are now explicitly `nonisolated`:

- HapticOutput
- MicrophoneFrame
- MicrophoneCaptureError
- MicrophoneAnalyzer
- MusicalClock
- PlaybackPlan

The microphone callbacks also capture one immutable engine reference rather than
a weak captured variable being referenced by nested concurrent tasks.

This removes the Swift-6-future-error diagnostics around `self`,
`PlaybackPlan.hostTime`, `firstEventIndex`, `requestClick`, `step` and
`recordedMidiNote`.

## AVAudioPlayerNode preview warning

The preview path moves the synchronous `scheduleBuffer` call into a synchronous
helper. The main metronome scheduler intentionally remains synchronous: it
pre-enqueues an absolute host-time runway and must not await each note's playback
completion.

## Xcode container logs

Do not add a UIKit `UIScene` manifest to the Watch app.

`MichiMetronome` is Apple's generated iPhoneOS distribution container for the
Watch-only product. During development, run the `MichiMetronome Watch App`
scheme on the Watch. Use the root `MichiMetronome` scheme only when archiving.

The `MessagesApplicationStub.xcassets ... Watch6,13` diagnostic comes from the
generated distribution stub being built against a Watch destination. For an
archive, use the generic distribution destination Xcode offers for the root
container rather than the physical Watch destination.
