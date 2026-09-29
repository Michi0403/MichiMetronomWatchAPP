# MichiMetronome 1.6.0 — musical timeline engine

## Why this is MIDI-style, not CoreMIDI playback

The Watch app now uses a MIDI-style fixed-resolution musical clock (960 ticks
per UI beat) as the timing model.

It intentionally does NOT use AVAudioSequencer, AVAudioUnitMIDIInstrument, or
AVAudioUnitSampler as the playback engine. Apple's MIDI sequencer/instrument
playback APIs are unavailable on watchOS. Core Audio remains the renderer.

That gives the useful part of MIDI architecture on Watch:
- musical ticks / event positions;
- tempo-derived absolute time;
- generated events;
- bar/beat grouping;
- a future place for note-on/note-off events;

without depending on unavailable Watch APIs.

## No cumulative timing drift

Previous versions generated the next host timestamp by repeatedly adding the
previous interval.

1.6.0 derives every event independently:

    event musical position
        -> absolute seconds from start
        -> absolute Core Audio host timestamp

Therefore rounding on beat N is never carried into beat N+1.

The scheduler keeps an 8-second Core Audio runway but can continue generating
events indefinitely. A future runtime-generated accompaniment can use the same
timeline instead of constructing a giant song in memory.

## Stall behavior

Audio is scheduled ahead on the absolute musical timeline.

Haptics and visual beat state use the same timeline but remain best effort.
If watchOS stalls their task, past live events are skipped instead of replayed.

## Tempo layout

The tempo grid is now:

    -5    +5
    -1    +1

Negative is always left and positive always right.

## Privacy manifest

`MichiMetronomeWatch/PrivacyInfo.xcprivacy` is included for the App Store
migration. It declares the current UserDefaults and system-uptime required-reason
API usage and declares no collected data/tracking.

IMPORTANT: this source package deliberately does not modify the hand-built
`project.pbxproj`. When moving into the canonical Xcode-generated Watch-only
project, add PrivacyInfo.xcprivacy to the Watch app target membership there.

## Xcode project

The existing project.pbxproj is preserved byte-for-byte.
