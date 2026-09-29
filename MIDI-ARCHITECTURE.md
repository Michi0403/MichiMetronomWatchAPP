# Internal note-event model

MichiMetronome uses MIDI note numbers as an internal musical representation,
without requiring external MIDI hardware.

Each manual event contains:
- rhythm timing;
- optional MIDI note number.

Mic recording creates rhythm + MIDI pitch.
Tap recording creates rhythm only.

Playback chooses:
- captured MIDI note when present;
- otherwise the user-selected Base Note.

MIDI pitch is converted to frequency with:

    frequency = 440 * 2^((midi - 69) / 12)

The resulting PCM note is scheduled on the same absolute Core Audio host-time
timeline as the metronome. Synthesis never becomes the clock.

This is the foundation for future velocity, duration/note-off, chords,
correct-note scoring, generated melodies and rolling indefinite compositions.
