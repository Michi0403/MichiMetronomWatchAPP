# MichiMetronome 1.5.1

## Apple Watch SE touch targets

The UI now favors finger-sized controls rather than visually tiny header buttons.

- Settings gear: 44 x 44 pt interaction target.
- Meter control: menu-style Picker with a minimum 52 x 44 pt interaction target.
- BPM card: larger tappable region.
- BPM/Manual mode buttons: larger minimum height.
- Manual-mode action buttons: larger minimum height where practical.

SwiftUI's interaction content shape is used for explicit hit testing.

## Meter selector

The separate meter sheet is removed.

The current time signature is now a true SwiftUI menu Picker in the main header.
Tapping the displayed meter opens the available signatures directly and the
selected value remains visible in the control.

## Tempo buttons

The -5, -1, +1, +5 controls are now a 2 x 2 grid on both the main BPM page and
the dedicated Crown page.

Each button gets a 44 pt minimum height, which is much easier to hit on an
Apple Watch SE than four narrow buttons squeezed into one horizontal row.

The Xcode project file is preserved byte-for-byte.
