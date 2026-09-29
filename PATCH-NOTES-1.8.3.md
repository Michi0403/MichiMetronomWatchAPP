# MichiMetronome 1.8.3 — Xcode 26.6 audio-session compatibility

Xcode 26.6 does not expose the newer asynchronous
`AVAudioSession.deactivate(options:completionHandler:)` API.

All session-deactivation paths now use:

    try session.setActive(
        false,
        options: [.notifyOthersOnDeactivation]
    )

The app still stops/resets audio objects first and waits briefly for the Watch
route/priority handoff before changing from playback to microphone or back.

This fixes:

    Value of type 'AVAudioSession' has no member 'deactivate'

and the follow-on contextual `notifyOthersOnDeactivation` error.

No musical timing or melody-detection behavior was changed from 1.8.2.
