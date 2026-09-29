# Michi Metronome

Native, standalone, offline Apple Watch metronome, rhythm recorder, pitch-aware
melody looper, and instrument tuner.

## Canonical Xcode project

Use this project from now on:

```text
MichiMetronome/MichiMetronome.xcodeproj
```

This is the **Xcode 26.6 generated Watch-only project**. It contains Apple's
distribution container target plus the real embedded Watch app target.

The older `MichiMetronomeWatch/` project remains in the repository only as
historical/source reference. Do not archive that project for TestFlight.

## Distribution identifiers

Registered App ID / root distribution container:

```text
com.michi0403.michimetronome
```

Embedded Watch app:

```text
com.michi0403.michimetronome.watchkitapp
```

Both targets use automatic signing with team `YS97976PCZ`.

Product version:

```text
1.0.0 (build 1)
```

Minimum deployment target: watchOS 26.0.

## Features

### Metronome

- 30–300 BPM.
- Absolute musical timeline; later events are calculated from musical position,
  not by repeatedly adding the previous interval.
- `-5 / +5` and `-1 / +1` tempo controls.
- Digital Crown tempo editing.
- Common and odd time signatures with a matching beat-marker strip.
- User-selectable base MIDI note.
- Wood, Sharp, Low and Beep synthesized timbres.
- Audible downbeat accent.
- Optional Watch haptic click.

### Manual rhythm

Fast melody capture uses a short onset refractory period and keeps a detected
pitch change pending until it is actually committed as a rhythm event.


Two independent recording paths remain available:

- **Tap** records exact finger-tap spacing.
- **Mic** detects note attacks from singing or an instrument and stores both
  the rhythm and optional MIDI note number.

Mic-recorded patterns play back the captured pitches. Tap-only patterns use the
selected Base Note.

### Instrument tuner

Settings includes an on-device tuner showing:

- nearest note;
- detected frequency;
- cents from equal temperament;
- input level.

Microphone audio is analyzed locally. Raw audio is not stored or uploaded.

## Privacy

`PrivacyInfo.xcprivacy` is part of the Watch target.

The current app declares:

- no tracking;
- no collected data;
- UserDefaults required-reason API usage;
- system uptime required-reason API usage.

The Watch target also includes the microphone purpose string and background-audio
mode in `MichiMetronomeWatch-Info.plist`, which Xcode merges into the generated
Info.plist at build time.

## Build and run on Apple Watch

1. Open `MichiMetronome/MichiMetronome.xcodeproj` in Xcode 26.6 or later.
2. Select the **MichiMetronome Watch App** scheme for normal development.
3. In Signing & Capabilities, confirm **Automatically manage signing** is enabled
   and team `YS97976PCZ` is selected.
4. Select your physical Apple Watch.
5. Product → Clean Build Folder.
6. Run.

On the first signed build, Xcode may create/manage the derived Watch App ID and
provisioning profile for `com.michi0403.michimetronome.watchkitapp`.

## TestFlight archive

For distribution, archive the **container**, not the bare Watch target:

1. Select the **MichiMetronome** scheme.
2. Use the generic distribution destination offered by Xcode for the Watch-only
   container.
3. Product → Archive.
4. In Organizer, select the archive and run **Validate App**.
5. Choose **Distribute App → TestFlight & App Store** and upload.

The container is an Apple-generated `watchapp2-container`; it has no iPhone UI
or executable content of its own. Its job is to package the Watch-only app for
App Store Connect/TestFlight.

In App Store Connect create/use the app record for:

```text
com.michi0403.michimetronome
```

After processing, add the build to an External Testing group, submit the first
external build for TestFlight Beta App Review, then enable a Public Link and send
that link to testers.

## Repository layout

```text
MichiMetronome/
  MichiMetronome.xcodeproj/       canonical Xcode 26.6 distribution project
  MichiMetronome Watch App/       current Watch source/assets/privacy manifest
  MichiMetronomeWatch-Info.plist  partial plist merged into generated Watch plist

MichiMetronomeWatch/
  legacy/reference project and source history

MIDI-ARCHITECTURE.md
PATCH-NOTES-*.md
TESTFLIGHT.md
Build.ps1
Validate.ps1
```


## Xcode 26.6 development vs distribution schemes

For ordinary Watch testing, select:

`MichiMetronome Watch App`

and run on the physical Apple Watch.

Do not run the root `MichiMetronome` distribution-container scheme on the Watch
as the normal development scheme. That root target is an Apple-generated
iPhoneOS packaging stub used to embed the Watch app for App Store Connect.

For TestFlight/archive, switch to the root `MichiMetronome` scheme and use the
generic distribution/archive destination Xcode offers. A UIKit `UIScene`
configuration should not be added to the Watch app merely to silence a container
runtime log.
