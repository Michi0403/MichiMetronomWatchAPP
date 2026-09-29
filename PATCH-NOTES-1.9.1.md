# MichiMetronome 1.9.1 — sub-buffer pitch analysis

## Root cause found by 1.9.0 telemetry

The physical Watch completed all delivered analysis callbacks with:

    dropped=0

but only about ten analysis passes per second occurred during a ~166 second
recording.

`AVAudioNode.installTap(bufferSize: 1024)` is a requested tap size, not a
guarantee that the hardware route will call the tap every 1024 frames.

Analyzing once per delivered Watch callback therefore discarded temporal
resolution even though no callback was technically "dropped".

## 1024-sample internal hops

Every delivered microphone buffer is now subdivided into 1024-sample analysis
chunks.

At 44.1 kHz this is about 23 ms per pitch observation.

Musical events are emitted for every analysis hop. SwiftUI display updates are
separately throttled to about 16 Hz except for note onsets, so the UI cannot
become the new bottleneck.

## Stabilization

Because observations are now much closer together, a note change always requires
two agreeing pitch observations (~46 ms at 44.1 kHz).

The previous one-frame fast path was removed. It was responsible for some short
wrong octave/transient notes during high descending passages.

## Midrange latency

The 1024-sample YIN estimate is now preferred from 180 Hz upward when confidence
is at least 0.82. This improves rapid B3/C4 and similar semitone changes that
previously fell back to a 2048-sample window.

## Telemetry

Mic start prints the actual sample rate.

Mic stop now prints:

    [MichiPitch] ANALYSIS_STATS callbacks=... inputFramesAvg=... inputFramesMin=... inputFramesMax=... analyzed=... dropped=... avgMs=... maxMs=...

The next benchmark will therefore tell us the exact buffer size watchOS actually
delivers and how many internal pitch observations were processed.

No UI/button/project-setting changes.
