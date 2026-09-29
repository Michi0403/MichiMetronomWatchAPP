# Michi Metronome — Watch Only 1.1

Native, standalone, offline watchOS metronome.

## Build

1. Delete the old DerivedData for this project:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/MichiMetronomeWatch-*
   ```
2. Open:
   `MichiMetronomeWatch/MichiMetronomeWatch.xcodeproj`
3. Select your Apple Developer team under **Signing & Capabilities**.
4. Select a Watch simulator or your physical Apple Watch.
5. **Product → Clean Build Folder**
6. Run.

The project already contains your previously configured development team ID. If this project is opened under another account/team, select the correct team again in Xcode.

## Modes

### BPM
Turn the Digital Crown to choose 30–300 BPM. The beat strip follows the current measure.

### Manual
Record a finger-tapped rhythm, then loop the actual spacing between taps. This is intentionally different from ordinary "tap tempo": uneven rhythms remain uneven.

## Background behavior

Enable **Sound** for supported watchOS background playback.

Apple's public API deliberately prevents ordinary `WKInterfaceDevice` haptics while the app is background/inactive. The project therefore pauses haptic-only playback on background and resumes it when the app becomes active again instead of claiming to do something watchOS ignores.

## Simulator

The simulator intentionally skips AVAudioEngine setup. The UI, scheduler, BPM controls, manual pattern recording and moving timeline can all be tested there, but audio/haptics must be validated on a physical Watch.

## Status notification

Enable **Settings → Notify when leaving** if you want a local notification showing the current mode/settings when you leave a running metronome.
