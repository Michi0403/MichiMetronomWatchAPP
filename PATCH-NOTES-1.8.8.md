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
