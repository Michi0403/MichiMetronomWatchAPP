# MichiMetronome 1.3.1

## Xcode 26.6 AVAudioSession compatibility

Xcode 26.6/watchOS 26 does not expose the newer
`AVAudioSession.deactivate(...)` API used by the previous source revision.

The project now uses the established API:

`setActive(false, options: [.notifyOthersOnDeactivation])`

Deactivation is dispatched off the main thread so it does not block the watch UI.

The uploaded/generated Xcode project file is not modified.
