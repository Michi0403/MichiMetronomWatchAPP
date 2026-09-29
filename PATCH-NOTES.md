# MichiMetronome 1.8.9 — remove legacy 32-event pattern limit

## Root cause

`MetronomeSettings.normalize()` still contained the historical:

    manualIntervals.prefix(32)

That silently truncated any Tap or Mic pattern to 32 events when settings were
normalized/saved.

The microphone event store itself was not stopping at 32.

## New limit

The old 32-event cap is replaced with:

    maximumManualEvents = 8192

This is a defensive sanity ceiling rather than a practical musical restriction.

At the minimum supported 60 ms event spacing, 8192 events represent more than
8 minutes of continuous events. At normal beat spacings the possible recording
length is much longer.

## Commit diagnostics

Mic pattern commit now logs:

    [MichiPitch] PATTERN_COMMIT captured=230 saved=230 notes=230 cap=8192

This makes any future truncation immediately visible.

## Pitch detector

No pitch thresholds, YIN behavior, button UI, Xcode target settings, or audio
session behavior were changed in this revision.


---

# MichiMetronome 1.8.8 — pitch debug timeline

No pitch thresholds or UI behavior were changed in this revision.

Each accepted microphone musical event now prints one structured line to the
Xcode console.

Example:

    [MichiPitch] CHANGE t=0.412s uptime=83451.224 note=E4 midi=64 freq=329.71Hz cents=+0.3 confidence=0.941
    [MichiPitch] REATTACK t=0.688s uptime=83451.500 note=E4 midi=64 freq=329.56Hz cents=-0.5 confidence=0.928

Fields:

- `CHANGE`: stabilized MIDI note changed; display + recorder changed together.
- `REATTACK`: a new articulation of the same displayed pitch.
- `t`: seconds since the first analyzed microphone frame in that recording.
- `uptime`: monotonic `ProcessInfo.systemUptime` timestamp.
- `note`: scientific pitch name.
- `midi`: MIDI note number.
- `freq`: detected fundamental frequency.
- `cents`: deviation from equal-tempered center of that MIDI note.
- `confidence`: pitch-estimator confidence.

Mic recordings also log:

    [MichiPitch] RECORDING_BEGIN ...
    [MichiPitch] RECORDING_END ... events=N

This makes it possible to compare a known MIDI note sequence and timing against
exactly what the Watch accepted.

No Xcode project settings or button/layout code were changed.


---

# MichiMetronome 1.8.7 — tuner-grade pitch path + lossless Mic events

## Pitch detector

The old detector selected the strongest normalized autocorrelation peak from a
single short block. That is vulnerable to harmonics and octave errors, especially
for singing.

1.8.7 replaces it with a YIN-style normalized difference estimator.

Pitch analysis now uses a rolling signal window:

- 2048 samples for responsive melody detection;
- 4096-sample fallback for low notes and uncertain signals;
- cheap averaging decimation to about 12 kHz;
- cumulative-mean normalized difference;
- first-threshold period selection instead of strongest harmonic;
- parabolic lag interpolation for more stable frequency/cents;
- octave sanity check between short and long windows.

The supported analysis range is approximately 40 Hz to 1800 Hz.

## Recording can no longer lose a displayed/accepted note because of UI load

Accepted musical events are now committed on the analyzer's serial queue BEFORE
the visual frame is delivered to SwiftUI/MainActor.

A locked `MicrophoneEventStore` owns those events until recording stops.

Therefore:
- UI rendering cannot drop an accepted note;
- tapping Use cannot commit before the final already-running analyzer block is
  flushed;
- event timestamps are sorted before rhythm intervals are built.

The note shown by the recorder still comes from the same stabilized MIDI-note
state as the captured event.

## UI

No button/layout changes in this revision.

The two `CoreUI: CUIThemeStore: No theme registered with id=0` framework log
lines are intentionally not being treated as the pitch/recording fault.


---

# MichiMetronome 1.8.6 — display-coupled melody recording

## Note display and recording now share one state machine

Previously, the tuner display and the recorder used slightly different pitch
transition criteria.

That allowed this failure mode:

    UI changes C4 -> D4
    recorder rejects the transition
    D4 is visible but never becomes a recorded event

The analyzer now keeps one `displayedMidiNote`.

A new note must be detected in two analyzed frames. Once that stable transition
is accepted, the same code path simultaneously:

1. changes `displayedMidiNote`;
2. emits a recording onset;
3. stores the transition timestamp.

Therefore a note-name change visible in the microphone recording UI cannot occur
without the corresponding melody event being recorded.

## Same-note repetition

Repeated attacks on the same note still use amplitude attack detection, because
the displayed note naturally does not change for C4 -> C4.

## Timing

The transition floor remains 60 ms, matching the persisted manual-rhythm floor.

## UI

No button styles or layouts were changed in this revision.

The CoreUI theme-store console line is not being chased with further UI-style
changes because the previous attempt to do so caused a real UI regression.


---

# MichiMetronome 1.8.5 — UI regression correction

This is a targeted correction to 1.8.4, not a rollback.

## Native Watch buttons restored

The custom `WatchFilledButtonStyle` and `WatchOutlineButtonStyle` introduced in
1.8.4 were removed. They made button backgrounds collapse to the text label on
the physical Watch and made the expected touch targets unclear.

The following controls are back on the native watchOS button styles that were
already working correctly:

- BPM / Manual mode buttons;
- Tempo Done;
- manual TAP / Cancel / Use;
- microphone Cancel / Use;
- Tuner Start/Stop / Done;
- Base Note Done.

## Start button during Mic/Tuner

The engine already prevented playback from starting while Mic/Tuner owned the
shared audio session. However `canStart` still reported true, so the green Start
button looked active even though the engine intentionally ignored it.

`canStart` now returns false while the microphone owns the audio session, and the
custom Start/Stop control visibly dims when disabled.

## Kept from 1.8.4

The fixes that address the actual runtime problems remain unchanged:

- playback does not steal AVAudioSession during Mic/Tuner;
- watchOS foreground transitions cannot cut off recording;
- microphone analysis queue is bounded;
- fast rhythm intervals down to 60 ms are preserved;
- Crown editors use explicit FocusState;
- Start/Stop no longer dynamically swaps SF Symbols;
- the unused AVAudioSession warning remains fixed.

No Xcode project settings were changed.


---

# MichiMetronome 1.8.4 — Watch runtime stability

## Recording cut-off / audio-session ownership

`becameActive()` and `prepareForUse()` no longer prepare the playback audio
session while Mic recording or the Tuner owns the shared AVAudioSession.

This matters on watchOS 26 because scene activity can bounce during UI/audio
transitions. A foreground callback must not change the category from `.record`
back to `.playback` during a recording.

The playback Start path is also blocked while a microphone session is active.

## Fast melody recording

The persisted manual interval floor is now 60 ms instead of 120 ms. The previous
120 ms normalization silently stretched fast notes even though the onset detector
could already identify them faster.

Manual synthesized note duration is also shorter for fast patterns so adjacent
notes do not crowd each other.

## Microphone analysis queue

Only one microphone PCM block may be waiting for analysis. If the Watch CPU is
still analyzing the previous block, a later analysis block is dropped instead
of building an ever-growing queue. This keeps pitch display latency bounded and
reduces UI/audio hangs.

## Digital Crown

Tempo and Base Note editors now use explicit `FocusState`. Crown focus is assigned
only after the modal view has mounted and is released when it disappears.

This addresses the watchOS runtime diagnostic:

    Crown Sequencer was set up without a view property.

## CoreUI / SF Symbol cache mitigation

The Start/Stop state icon no longer swaps between dynamic SF Symbols. It is drawn
using SwiftUI shapes.

The stateful recording/tuner controls also use plain custom SwiftUI button styles
instead of themed bordered/prominent styles on those hot paths. This reduces
CoreUI theme-store work during start/stop/record transitions.

## Compiler warning

Removed the unused `AVAudioSession` local from `MicrophoneAnalyzer.startEngine`.

## Notes about system diagnostics

Current Apple platform builds have reports of `fopen failed for data file`
messages when SF Symbols change dynamically. 1.8.4 removes that dynamic symbol
swap from the playback control. Remaining OS-originated CoreUI/cache diagnostics,
if any, should be evaluated separately from application audio-session failures.


---

# MichiMetronome 1.8.3 — Xcode 26.6 audio-session compatibility

Xcode 26.6 does not expose the newer asynchronous
`AVAudioSession.deactivate(options:completionHandler:)` API.

All session-deactivation paths now use:

    try session.setActive(
        false,
        options: [.notifyOthersOnDeactivation]
    )

The app still stops/resets audio objects first and waits briefly for the Watch
route/priority handoff before changing from playback to microphone or back.

This fixes:

    Value of type 'AVAudioSession' has no member 'deactivate'

and the follow-on contextual `notifyOthersOnDeactivation` error.

No musical timing or melody-detection behavior was changed from 1.8.2.


---

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


---

# MichiMetronome 1.8.1 — distribution project migration

No timing/synthesis behavior was changed in this revision.

## Distribution architecture

The current 1.8.0 application code has been transplanted into a fresh Xcode 26.6
Watch-only project generated by Xcode itself.

The generated project contains:

- root distribution container target `MichiMetronome`;
- embedded Watch target `MichiMetronome Watch App`;
- Apple-generated Embed Watch Content build phase;
- Apple-generated target dependency and product types.

## Bundle identifiers

Root/container:

`com.michi0403.michimetronome`

Watch app:

`com.michi0403.michimetronome.watchkitapp`

## Release metadata

Marketing version: `1.0.0`

Build: `1`

Deployment target: watchOS 26.0.

## Distribution resources

The canonical Watch target now contains:

- current Swift application code;
- current 1024x1024 Watch app icon;
- `PrivacyInfo.xcprivacy`.

`MichiMetronomeWatch-Info.plist` is a partial plist outside the synchronized
source group and is merged into Xcode's generated Watch Info.plist. It supplies:

- `NSMicrophoneUsageDescription`;
- `UIBackgroundModes = audio`;
- `ITSAppUsesNonExemptEncryption = false`.

The Background Modes capability is marked on the generated Watch target.

## Repository

`MichiMetronome/MichiMetronome.xcodeproj` is now the canonical project.

The older `MichiMetronomeWatch/` project is retained only as historical/source
reference and should not be used for TestFlight archives.


---

# MichiMetronome 1.1.2

## Xcode 26 async-alternative warning fix

Xcode warned:

`Consider using asynchronous alternative function`

for the looping `AVAudioPlayerNode.scheduleBuffer(...)` call inside the async
audio-session startup function.

The async overload is intentionally *not* used for the keep-alive buffer because
that buffer uses `.loops`. Awaiting an indefinitely looping buffer is not the
desired lifecycle.

The scheduling call now lives in a synchronous helper method, eliminating the
concurrency migration warning while preserving continuous background-audio
keep-alive behavior.

# MichiMetronome 1.1.1

## Swift 6 / Xcode 26 audio overload fix

`AVAudioPlayerNode.scheduleBuffer` exposes both synchronous and async overloads.
The previous code omitted the completion handler, which allowed Swift 6 to select
the async overload and produced:

`Expression is 'async' but is not marked with 'await'`

Both scheduling calls now explicitly pass `completionHandler: nil`, forcing the
synchronous overload. This is intentional because these calls only enqueue audio
buffers and must not suspend the metronome scheduler.

# MichiMetronome 1.1.0

## Functional fixes

- Uses a real explicit watchOS `Info.plist` with `WKApplication = true` instead of relying on generated plist keys.
- Stable executable/app bundle filename: `MichiMetronomeWatch.app`.
- Removes synchronous `AVAudioSession.setActive(true)` from the main thread and uses watchOS async audio activation.
- Does not create CoreAudio objects in the watchOS simulator, avoiding misleading simulator-only audio factory noise.
- Digital Crown control now has explicit SwiftUI focus state.
- Background audio mode is declared.
- Haptic output checks `WKApplication` state and does not pretend watchOS can play ordinary haptics in the background.

## UI

- Fixed BPM mode, 30–300 BPM.
- Digital Crown tempo selection.
- ±5 BPM buttons.
- Meter indicator and meter cycling.
- Start/stop control.
- Settings for haptics, sound, accent, and background status notification.

## Manual rhythm mode

- Press **Record**.
- Tap the large **TAP** button in the rhythm you want.
- Press **Use** after at least two taps.
- The exact inter-tap gaps are stored as a repeating rhythm.
- A simple timeline shows the recorded beat positions and a moving playback cursor.
- The final loop-back gap uses the median recorded spacing so the last tapped beat is preserved as a beat in the loop.

## Background limitation

watchOS does not allow a normal app to emit `WKInterfaceDevice` haptics while the app is inactive/background.
Audible playback can continue using the supported background-audio path. Haptic-only playback pauses and resumes when the app becomes active again.

The optional local status notification shows the current BPM/manual pattern when leaving the running app.
