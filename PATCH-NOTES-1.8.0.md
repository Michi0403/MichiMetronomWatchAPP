# MichiMetronome 1.8.0 — pitched MIDI-like playback

Mic-recorded patterns now play the captured MIDI pitches instead of discarding
the note information and using a fixed click.

Tap-recorded patterns and normal BPM metronome playback use a new user-selectable
Base Note. Default: A4 / MIDI 69.

Settings > Output > Base note opens a dedicated Watch screen with:
- Digital Crown semitone control;
- -12 / +12 octave buttons;
- -1 / +1 semitone buttons;
- Hear preview.

The existing Wood / Sharp / Low / Beep selection now changes the harmonic
character of the pitched note.

The first-beat accent remains louder/brighter without transposing the pitch.

Timing is unchanged from the absolute musical timeline introduced in 1.6:
the synth buffer is only the payload scheduled at each exact host timestamp.

While a Mic-recorded manual pattern plays, the current captured note is displayed
on the Manual screen as it sounds.

Generated note buffers are cached and the cache is bounded to protect Watch
memory.

The Xcode project file is preserved byte-for-byte.
