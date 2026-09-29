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
