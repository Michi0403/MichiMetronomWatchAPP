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
