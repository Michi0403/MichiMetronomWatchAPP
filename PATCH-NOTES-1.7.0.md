# MichiMetronome 1.7.0 — microphone notes + tuner

## Existing tap recorder preserved

Manual rhythm now has two independent recording paths:

- Tap
- Mic

Tap behaves as before and creates rhythm-only events.

Mic listens for played/sung attacks and stores an optional MIDI note number next
to every detected rhythm event.

## Instrument tuner

Settings now includes Instrument Tuner.

It shows:
- nearest note name;
- frequency in Hz;
- cents from the nearest equal-tempered note;
- microphone signal level.

The Mic rhythm recorder shows the same live pitch information while recording.

## Pitch/onset analysis

The Watch microphone is captured with AVAudioEngine inputNode.

Analysis is local:
- RMS amplitude;
- downsampled normalized autocorrelation pitch estimate;
- attack detection from envelope rise;
- note-change detection for legato note changes;
- 120 ms onset refractory period.

Pitch range is approximately A1 (55 Hz) through A6 (1760 Hz).

## Audio session behavior

Mic/tuner recording intentionally stops the metronome audio session first and
uses an AVAudioSession recording/measurement session.

This prevents the Watch speaker click from being detected as the user's
instrument. When mic/tuner mode ends, normal metronome playback is prepared
again.

## Privacy

Info.plist now includes NSMicrophoneUsageDescription.

Raw microphone audio is not stored and is not uploaded. Only derived local
rhythm intervals and optional MIDI note numbers are persisted in UserDefaults.

The existing privacy manifest still declares no collected data/tracking because
the app does not transmit this information off-device.

## MIDI-style note model

MetronomeSettings now persists `manualMidiNotes: [Int?]`, aligned one-for-one
with manual rhythm events.

This is the foundation for a later synth/accompaniment layer. 1.7 intentionally
does not replace the now-stable click renderer with a new note synthesizer yet.

## Project

The Xcode project file is preserved byte-for-byte.
