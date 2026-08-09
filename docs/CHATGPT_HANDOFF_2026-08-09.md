# Palette / Wave Explorer ChatGPT Handoff — 2026-08-09

## Purpose

This document is the current technical handoff for ChatGPT or Claude. It records what is actually working, what was changed, what remains uncertain, and the next safe milestone. The goal is to let another model back up implementation and architecture work without repeating the early bring-up steps.

## Project locations

- Documentation Git checkout: `/Users/keegan/Documents/!Clicky/palette`
- Live Swift package: `/Users/keegan/Cassel Bear Dropbox/Keegan Bear/!Palette/_Program/WaveExplorer_V2`
- GitHub remote: `https://github.com/Keegandabear/Palette.git`
- Tangent SDK sample source: `/Users/keegan/Cassel Bear Dropbox/Keegan Bear/!Palette/Tangent Dev/tagent deeloper support pack/TUBE Development Support for OSX v3.12/SampleCode/main.c`

Important: the documentation checkout and the live Swift package are currently separate locations. Do not claim the Swift source has been pushed to GitHub unless the live source is explicitly committed and pushed.

## Verified hardware milestone

- Tangent Hub is running as a background agent.
- The Hub is reachable at `127.0.0.1:64246`.
- Wave Explorer connects through TIPC and completes the Hub handshake.
- Panel discovery and panel capabilities work.
- The Wave's buttons, encoders, transport dial, and trackball axes produce decoded events.
- The physical Wave was exercised by pressing buttons, moving controls, and using the trackball; events appeared in the app log.
- The Wave OLED panel is identified as panel ID `0xA0001`.
- The OLED capability response reports three displays, each five lines by 32 characters.
- OLED writes are batched into one refresh response for display numbers `0`, `1`, and `2`.
- All three OLEDs can display `Wave Explorer`.
- The boxed final `r` that appeared after the first label test was caused by the SDK's `0x80` inverted-text flag being applied to ordinary text. Normal text now uses plain bytes; intentional inverted text remains available through a separate writer.

## Current code structure

The live package contains these main layers:

- `TIPCClient.swift`: TCP connection, handshake, message send/receive, and display-write batching.
- `TIPCWireFormat.swift`: big-endian reader/writer and wire-level commands, including normal and inverted OLED strings.
- `TIPCFraming.swift`: packet framing and extraction from partial TCP reads.
- `DeviceManager.swift`: connection state, panel capabilities, control list, OLED test action, event diagnostics, and panel-aware naming.
- `HardwareControl.swift`: wire-faithful encoder/button/display model used by the SwiftUI debug view.
- `WaveControlNaming.swift`: Wave control-number to friendly-name lookup based on the supplied `wave-map.xml`.
- `WaveEvent.swift`: typed decoded events and human-readable log formatting.
- `EventLogger.swift`: unified logging plus an in-memory recent-event ring buffer.
- `OLEDManager.swift`: queued per-panel/per-display labels used when Hub requests a refresh.
- `DebugView.swift`: small developer UI for connection status, capabilities, mapping status, detected controls, OLED test writing, and recent/live events.

`WaveExplorerCore` intentionally stays headless so Palette can reuse the transport and device layers later.

## Work completed in this session

### Expanded Wave mapping

`WaveControlNaming.swift` now includes all distinct physical control numbers present in the sample Wave map:

- Encoders `0` through `7`: Knobs 1 through 8.
- Encoder `9`: Dial 1 / Trackball 1 Rotate.
- Encoder `12`: Transport Dial.
- Encoders `13` and `14`: Trackball 1 X and Y.
- Buttons `9`, `10`–`12`, `20`–`22`, `25`, `26`, `30`, `31`, `33`–`40`.

The sample map contains multiple banks, so the same physical number can have different semantic assignments depending on the active mode. The lookup intentionally names the physical control rather than pretending to know the current managed-mode assignment.

### Panel-aware naming

Wave names are only applied when the panel is recognized as the Wave by either:

- known panel ID `0xA0001`, or
- the verified Wave OLED shape of three displays, five lines, and 32 characters.

Unknown panels still display generic `Encoder N` / `Button N` labels instead of receiving Wave-specific guesses.

### Live diagnostic

The debug view now shows:

- whether Wave mapping is active or generic numbering is being used;
- the latest decoded hardware event, including the friendly mapped name when appropriate.

This makes the next physical-control verification easier: one control can be moved or pressed and the exact event name can be read immediately.

## Validation status

After this session, the package has a successful build and ten passing tests, including mapping and panel-recognition coverage. The required validation commands are:

```text
cd "/Users/keegan/Cassel Bear Dropbox/Keegan Bear/!Palette/_Program/WaveExplorer_V2"
swift test
swift build --product WaveExplorerApp
```

Run both after the source changes. If the package is open in Xcode, the same result should appear in the WaveExplorerApp scheme.

## Remaining limitations

- The Hub's capabilities response gives counts, not a complete named physical inventory. Friendly names still come from the sample `wave-map.xml` plus live verification.
- The sample map has banks and modes. The current unmanaged explorer does not yet expose active managed-mode/bank state, so it cannot infer the semantic assignment of every encoder at every moment.
- Trackball 2 and Trackball 3 names are not yet confirmed in the map or live event log.
- There is no persistent structured session export yet; recent events are in memory and also available through macOS unified logging.
- No Resolve adapter, DCTL/OFX mapping, Palette product UI, Capture One adapter, or plugin-mode ownership work should begin yet.
- The live Swift package remains outside the documentation Git checkout. Keep source and docs locations explicit.

## Recommended next milestone

The next milestone should be a controlled mapping-verification pass, not a broad Palette UI build:

1. Run `swift test` and `swift build --product WaveExplorerApp`.
2. Launch Wave Explorer with the Wave connected and verify that the debug view says `Wave mapping active`.
3. Move one knob, press one function button, rotate the transport dial, and move each available trackball axis.
4. Confirm the live diagnostic names match the physical control and record any mismatches.
5. Add only verified corrections to `WaveControlNaming.swift`.
6. Add fixture tests for every confirmed control name.
7. Then add a small JSONL or Markdown session export so a hardware run can be handed to another model without screenshots.

The user should only be asked to touch the hardware for this short verification pass. Everything else in the milestone can be implemented and tested autonomously.

## Guidance for ChatGPT / Claude

Please review this handoff together with:

- `docs/HANDOFF.md`
- `docs/KNOWN_FACTS.md`
- `docs/MASTER_PLAN.md`
- `docs/NEXT_STEPS.md`
- `docs/LIVE_CHECK_2026-08-08.md`
- the live package README
- Tangent SDK `SampleCode/main.c`

Keep the scope on verified TIPC and Wave hardware behavior. Do not replace the working transport with guessed protocol values. Do not treat the sample map as an exhaustive Tangent hardware reference. Do not start Resolve or DCTL integration until the hardware explorer has stable mapping, diagnostics, and reproducible tests.

## Plain-English status

Wave Explorer is no longer just a connection experiment: it connects to the real Wave, discovers its capabilities, receives live controls, and writes all three OLED labels. The remaining work is to turn the working readout into a reliable, documented hardware foundation that Palette can safely reuse.
