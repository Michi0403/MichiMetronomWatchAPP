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
