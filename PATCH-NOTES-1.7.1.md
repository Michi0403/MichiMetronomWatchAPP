# MichiMetronome 1.7.1

## Compile fix

`manualMidiNotes` is `[Int?]`. Swift 6 could not infer the result type of the
nested optional `compactMap` closure in `manualNoteSummary`.

The closure and result array now have explicit types:

    let names: [String] = settings.manualMidiNotes.compactMap {
        (note: Int?) -> String? in
        ...
    }

This fixes:

    Generic parameter 'ElementOfResult' could not be inferred

## Microphone permission API

The deprecated:

    AVAudioSession.sharedInstance().requestRecordPermission

has been replaced by:

    AVAudioApplication.requestRecordPermission

which is the current AVFAudio API for microphone permission.

## Project

The Xcode project file is preserved byte-for-byte.
