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
