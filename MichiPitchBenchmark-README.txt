Michi Pitch Benchmark MIDI

Tempo: 120 BPM
Time signature: 4/4
Resolution: 480 ticks per quarter
Program: General MIDI Acoustic Grand Piano
Total expected note events: 504
Approx. duration: 159.8 seconds

How to use it with the Watch:
1. Start the Watch Mic recorder.
2. Start MIDI playback after the 2-second lead-in.
3. Keep speaker/watch position fixed.
4. Copy all console lines beginning with [MichiPitch].
5. Compare them with MichiPitchBenchmark-reference.csv.

Sections:
01_range_anchors
  Sustained notes from E1 (~41 Hz) through A6 (1760 Hz).

02_chromatic_up_E1_to_A6
03_chromatic_down_A6_to_E1
  Every semitone in the main detector range.

04_octave_and_wide_leaps
  Octaves and large interval jumps.

05_semitone_trills
  Repeated adjacent-note changes.

06_same_note_reattacks
  Same A4 with increasingly fast repeated attacks.

07_fast_16th_scale
  125 ms note spacing.

08_32nd_note_stress_62ms
  62.5 ms note spacing, deliberately close to the 60 ms recorder floor.

09_arpeggios
  Larger harmonic jumps and overtone-rich interval patterns.

10_velocity_dynamics
  Same notes at MIDI velocities 35 through 127.

11_long_sustains
  Tuner stability test.

12_boundary_stress
  Includes some notes below/above the current nominal ~40–1800 Hz range.

Important:
MIDI itself does not define the exact sound. The benchmark uses GM Acoustic Grand
Piano program 0, but the actual timbre depends on the MIDI player/synth you use.
For repeatable comparisons, use the same player, instrument, volume, distance,
and room each time.
