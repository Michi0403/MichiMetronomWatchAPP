# MichiMetronome 1.9.0 — accelerated pitch analysis

## Why

The clean no-click benchmark proved that pattern persistence is fixed
(`captured == saved`), but fast passages still lose many notes.

The previous YIN implementation evaluated every candidate lag with nested Swift
loops. On Apple Watch that can hold the analyzer long enough for the real-time
audio tap to drop later 1024-sample blocks.

## Accelerate/vDSP

The YIN difference function now computes each lag correlation with Apple's
Accelerate `vDSP_dotpr`.

Energy terms use a prefix-sum table, so each lag is:

    E(x) + E(y) - 2 * dot(x, y)

instead of an inner Swift sample loop.

## Adaptive windows

- 1024 samples for >= ~300 Hz: lower transition latency at high pitches.
- 2048 samples for midrange.
- 4096 samples for low/uncertain notes.
- Low-window harmonic comparison recognizes 2x/3x/4x relationships, reducing
  octave/harmonic mistakes for E1/A1/etc.

## Transition filtering

Large pitch leaps now require either:
- a detected amplitude attack, or
- confidence >= 0.88.

This is intended to reject short low-frequency resonance artifacts between
otherwise clean notes without blocking real attacked octave/wide jumps.

A high-confidence attacked note can commit after one analyzed frame; other note
changes still require two stable frames.

## Same-note reattacks

The amplitude-attack ratios were relaxed from 1.22/1.28 to 1.10/1.08. The
60 ms refractory interval still prevents duplicate events from one attack.

## Analyzer telemetry

Every microphone stop now prints:

    [MichiPitch] ANALYSIS_STATS analyzed=N dropped=N avgMs=X maxMs=Y

This directly tells us whether the physical Watch is keeping up with the incoming
audio blocks.

No UI/button/project-setting changes in this revision.
