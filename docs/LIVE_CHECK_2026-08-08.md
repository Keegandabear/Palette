# Wave Explorer Live Check — 2026-08-08

This check was performed on the Mac while the Wave Explorer project was open in Xcode.

## Tangent status

- `TangentHub` is running as a background process.
- `Tangent HUD Agent` is running as a background process.
- The HUD Agent application declares itself as a menu-bar/background app, so it is expected not to open a normal window or show a Dock dot.
- Tangent Hub is listening on local TCP port `64246`.
- A direct local connection test to `127.0.0.1:64246` succeeded.

This means the missing Tangent Hub pop-up is not currently evidence of a failure. The Hub service is alive and accepting connections.

## Wave Explorer status

- Project location currently open in Xcode: `WaveExplorer_V2`.
- Xcode's last visible build status changed to `Build Succeeded` today.
- The package contains `TIPCClient.swift`, `TIPCFraming.swift`, and `TIPCWireFormat.swift`; there is no `TIPCPacket.swift` in this version.
- `swift test` completed successfully.
- Six tests passed: three TIPC/wire-format tests and three event-log tests.
- The working tree was clean; no source code was changed during this live check.

## What this proves

The computer is ready for the next real test: launch Wave Explorer visibly from Xcode and see whether the app reaches `Ready`, lists a panel, reports capabilities, and logs an event when a Wave control moves.

The next failure, if there is one, should be an application-level connection or handshake issue—not “Tangent Hub is not open.”

## Additional Xcode finding

Xcode was initially using the `WaveExplorer-Package` scheme, which builds the package but does not launch the SwiftUI debug app. The active scheme was switched to `WaveExplorerApp`.

The remaining checkpoint is manual because the background Xcode session does not expose the newly launched SwiftUI window: bring Xcode to the front, click the Run triangle once, and watch for the `Wave Explorer` window. If it appears, no Wave control movement is needed until the window shows `Ready` or an error.

## Live hardware result

After switching to `WaveExplorerApp` and running it, Xcode's live console reported:

`Panel 0x140001 Capabilities — 55 buttons, 3 encoders, 55 displays (1x10)`

This confirms the TCP connection, Hub handshake, panel discovery, and capability request are all working with the connected hardware. The next manual action is to move one knob, press one button, or move the trackball and watch for a new event line.

## Event and OLED verification

- The live app logged button press/release events across the Wave.
- The live app logged encoder deltas, including the named `Knob 1` control.
- The event list showed named controls such as `Play Reverse`, `Stop`, and `Play Forward`.
- A reversible OLED test path was added to `DeviceManager` and the debug UI.
- The new `Write Test Label` button was loaded in the rebuilt app and pressed while connected.
- The six existing package tests still pass after the OLED wiring change.

The only physical confirmation left for this milestone is looking at the Wave's OLED display and checking whether it shows `Wave Explorer`.

## OLED troubleshooting and fix

The Tangent SDK sample revealed two details that the first test path was missing:

1. Unmanaged display strings mark the final text byte with `0x80`.
2. Hub can report multiple logical panels with displays; writing only to the last panel ID is not enough.

Wave Explorer now matches the SDK's final-byte marker, records every display-bearing panel ID from its own capabilities response, and sends the test label to each of those panels. The wire-format test suite covers the marker, and all seven package tests pass.

The live UI then showed `Sent 125 OLED writes` because the first multi-panel implementation wrote to every logical display-bearing panel reported by Hub. The capability list identifies the actual three-OLED Wave panel as `0xA0001` with `3 displays (5×32)`, so the write path was narrowed to that unique capability signature. The next test will send exactly three writes: display numbers `0`, `1`, and `2` on panel `0xA0001`.

If those three physical OLEDs still say `Tangent` after the targeted test, the remaining issue is likely the exact unmanaged display-refresh/write behavior rather than the connection, handshake, or event transport. The app now shows the number and panel IDs of the writes it actually sent, so this can be diagnosed without guessing.

The latest live test queued exactly `3` writes to `0xA0001 (3)` and automatically reconnected Wave Explorer. The Hub then issued a fresh `Display Refresh Requested (panel 0xa0001)` event, which is the correct protocol timing for the queued label. The only remaining confirmation is visual: whether the three physical OLEDs changed from `Tangent`.

## Follow-up — 2026-08-09

The far-right physical OLED now visibly says `Wave Explorer`, proving the protocol and panel selection are correct. The remaining two displays were not yet confirmed, so the outbound display response was changed to batch display numbers `0`, `1`, and `2` into one framed refresh reply for panel `0xA0001` instead of sending three separate TCP messages. The seven existing tests still pass and the Xcode product rebuild succeeds.

The next live observation found a boxed final `r` on each label. That was caused by treating the SDK sample's `0x80` final-byte inversion example as required for ordinary text. Normal OLED strings now use plain bytes; the inverted form remains available separately for intentional highlighted text. The test suite now has eight passing tests, including both encodings.
