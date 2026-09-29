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
