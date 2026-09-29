# MichiMetronome 1.4.0

Based on the last working 1.3.1 source. The Xcode project file is preserved.

## Haptic startup freeze

The physical Watch logged:

`CHHapticEngine doStartEngineAndWait: ERROR: Startup timeout`

The app previously called `WKInterfaceDevice.play(.click)` from the MainActor.
If watchOS blocked while starting its internal haptic engine, the entire UI and
metronome task could stall.

1.4.0 routes haptic playback through a dedicated serial queue. Only one haptic
call may be in flight. Beats that arrive while the Watch haptic stack is blocked
are dropped rather than queued. If one haptic call takes more than 250 ms, the
haptic output waits two seconds before retrying.

Audio/metronome timing therefore continues even if the Watch haptic service is
having a bad moment.

## No catch-up burst

If the app/debugger/system delays a beat beyond its deadline, the scheduler now
re-anchors one full interval into the future. It never emits multiple delayed
beats rapidly in an attempt to catch up.

## Scrolling and Apple Watch SE layout

The main screen is a ScrollView again and uses smaller controls/fonts suitable
for the Apple Watch SE.

The main Digital Crown conflict is removed: the scroll view owns the crown for
normal scrolling. Tap the BPM card to open a dedicated Tempo screen; that screen
has no ScrollView and owns the crown exclusively.

This keeps:
- normal scrolling on small Watches;
- Digital Crown BPM editing;
- no simultaneous scroll/crown gesture ownership.

## Audio startup / memory

Audio is prepared asynchronously when the app becomes usable instead of being
awaited before the metronome loop starts.

The continuous silent keep-alive buffer is only played while the app is actually
in the background. Foreground playback doesn't run the extra loop.

Generated audio uses 22.05 kHz instead of 44.1 kHz because a short metronome
click doesn't benefit meaningfully from the larger in-memory PCM representation.

The Xcode project file was not modified.
