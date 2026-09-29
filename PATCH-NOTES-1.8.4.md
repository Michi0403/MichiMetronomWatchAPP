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
