# Palette Readout — 2026-08-08

## Verified repository state

- Repository: `Keegandabear/Palette`, default branch `main`.
- Palette v1 targets DaVinci Resolve Studio first; Capture One is postponed.
- Resolve keeps native Tangent grading ownership.
- Palette is intended to control DCTL/OFX/plugin parameters through Tangent TIPC.
- Workspace and plugin mappings should be data-driven rather than hard-coded.
- The repository is currently documentation-first. The only substantive implementation guidance is in `docs/sessions/2026-08-04.md`; no Swift sources or TIPC constants are present in this checkout.

## Visible Xcode context

The open Wave Explorer package is a separate hardware-verification milestone, not Palette itself. Its stated job is to verify communication with a Tangent Wave over TIPC before Palette is built on top of the reusable core.

The visible structure separates:

- `TIPCClient.swift`: socket and handshake.
- `TIPCWireFormat.swift`: big-endian reader/writer and command bytes.
- `TIPCFraming.swift`: stream framing, header, and command encoding/decoding.
- `DeviceManager.swift`: connection/control state.
- `HardwareControl.swift`: hardware control model.
- `WaveControlNaming.swift`: control-number to friendly-name mapping.
- `EventLogger.swift` and `WaveEvent.swift`: event logging and typed decoded events.
- `OLEDManager.swift`: outbound label writes only.
- A thin SwiftUI shell and debug view.

`WaveExplorerCore` intentionally has no SwiftUI/AppKit imports so Palette can reuse it headlessly. The Xcode README says the wire implementation is being checked against Tangent's SDK `MockApplication`, not guessed; unresolved behavior should remain explicitly marked as open.

## Visible Claude guidance

Claude's visible message says Tangent Hub is Tangent's background/menu-bar driver. The intended flow is:

1. Install and launch Tangent Hub.
2. Confirm Hub detects the Wave over USB.
3. Launch Palette/WaveExplorer and connect to Hub over TIPC, described as a local TCP connection.

Claude also flags two checks: the app may need to be registered with Hub, and `DeviceManager.swift` must use the host/port that Hub actually exposes. Those are suggestions, not verified repository facts.

## Visible ChatGPT guidance

The visible architecture summary agrees that documentation exists, actual TIPC communication is the next major hurdle, Resolve integration and DCTL/OFX control come later, and Capture One is outside v1. The recommended division is Claude for implementation, ChatGPT for architecture/verification, GitHub as source of truth, and Keegan as product owner/tester.

## Recommended next sequence

1. In Wave Explorer, read the Tangent SDK `SampleCode`, `ReadMe.txt`, and `MockApplication` protocol behavior; do not infer packet values from screenshots or guesses.
2. Implement and test the smallest TIPC transport slice: connection target, handshake, big-endian primitives, header/length-prefixed framing, and one known request/response.
3. Add tests using captured or fixture packets from the SDK mock, including partial reads, multiple packets in one read, invalid lengths, and disconnects.
4. Run the Wave Explorer against Tangent Hub with the physical Wave connected; record the actual host/port, registration requirement, handshake result, and first decoded event.
5. Only after transport is stable, enumerate controls, log typed events, and test OLED label writes.
6. Commit that hardware-verification milestone before starting Palette Core, Resolve mode switching, DCTL, or OFX work.

## Open questions to verify, not assume

- Exact Hub host, port, registration mechanism, and connection mode.
- TIPC handshake bytes, command identifiers, header layout, length semantics, and endianness for every field.
- Reconnect and ownership behavior when Resolve and Wave Explorer are both running.
- Which control/event identifiers correspond to each physical Wave control.
- OLED write limits and acknowledgement behavior.
- How Palette can enter plugin mode without competing with Resolve's native grading integration.

## Current boundary

The immediate deliverable is a working, test-backed Wave Explorer transport and hardware readout. Resolve adapters, DCTL/OFX mappings, workspace UI, Capture One support, and broad product architecture should remain postponed until that foundation is verified.
