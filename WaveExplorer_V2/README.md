# Wave Explorer

A minimal macOS/SwiftUI tool whose only job is to verify communication with
a Tangent Wave over TIPC. It is **not** Palette. It does not touch Resolve,
does not know about DCTLs, and builds no product UI. Palette is built on
top of `WaveExplorerCore` later — this milestone exists to de-risk that
foundation.

The wire protocol implementation in this package is verified against
Tangent's own `MockApplication` (`main.c`, from the Developer Support
Pack) — not guessed. Where something is still open, it's called out
explicitly below rather than filled in with a plausible-looking guess.

## Folder layout

```
WaveExplorer/
├── Package.swift
├── Sources/
│   ├── WaveExplorerCore/            # No SwiftUI. This is what Palette reuses.
│   │   ├── TIPC/
│   │   │   ├── TIPCClient.swift         # socket + handshake, nothing else
│   │   │   ├── TIPCWireFormat.swift     # big-endian reader/writer, command bytes
│   │   │   └── TIPCFraming.swift        # stream framing + command decode
│   │   ├── Device/
│   │   │   ├── DeviceManager.swift      # connection/control state, published
│   │   │   ├── HardwareControl.swift
│   │   │   └── WaveControlNaming.swift  # control-number -> friendly name
│   │   ├── Logging/
│   │   │   ├── EventLogger.swift
│   │   │   └── WaveEvent.swift          # decoded, typed event model
│   │   └── OLED/
│   │       └── OLEDManager.swift        # outbound label writes only
│   └── WaveExplorerApp/             # SwiftUI shell, thin on purpose
│       ├── WaveExplorerApp.swift
│       └── DebugView.swift
├── Resources/ControlMap/            # unused while running unmanaged — see below
└── Tests/WaveExplorerCoreTests/
```

`WaveExplorerCore` has no import of SwiftUI or AppKit. Palette links
against Core and builds its own UI (or none at all, if it's driving DCTL
parameters headlessly) without dragging in a debug window.

## Managed vs. unmanaged — and why WaveExplorer runs unmanaged

Tangent's Hub has two modes, and this distinction is the single biggest
thing to get right before writing more code:

- **Managed mode** — your app ships an XML control map (`Controls.xml` +
  a per-panel map like `wave-map.xml`) declaring abstract application
  concepts (parameters, menus, actions, modes) and their default mapping
  onto specific physical controls. The Hub owns translating "trackball 1
  moved" into "Primary Lift Diff X changed" for you, and end users can
  re-map physical controls to your app's concepts with Tangent Mapper.
  This is almost certainly what **Palette** wants eventually — DCTLs and
  OFX parameters are exactly the kind of abstract, user-remappable
  concept this mode is built for.
- **Unmanaged mode** — your app gets raw control numbers directly: which
  panel, which button/encoder number, nothing more. No XML required.
  This is what a *bring-up/verification* tool wants, and it's what
  WaveExplorer uses (`SendApplicationDefinition` with empty sys/usr dir
  paths — see `TIPCClient.sendApplicationDefinition()`).

Concretely, unmanaged mode means: "enumerate every hardware control" is
answered by `IPC_HUB_COMMAND_UNMANAGED_PANEL_CAPABILITIES` — a **count**
per class (buttons, encoders, displays), not a named list. There is no
wire-level concept of "trackball" or "ring" at all: a trackball's X axis,
Y axis, and rotation each arrive as an ordinary `unmanagedEncoderChange`
on their own control number. `WaveControlNaming` is where "Encoder 13" is
translated to "Trackball 1 X" for display — confirmed for trackball 1 and
a handful of buttons/knobs from the sample `wave-map.xml` you provided;
the rest (trackballs 2 & 3, remaining buttons) still need filling in,
either from Tangent's hardware reference or by pressing every physical
control once with WaveExplorer running and reading the number off the log.

## Why each class exists

- **TIPCClient** — the only thing that touches `Network.framework`. Owns
  connect/disconnect, the mandatory handshake (Hub speaks first with
  `INITIATE_COMMS`; we reply with our application definition, then request
  capabilities per panel), and raw send. Deliberately doesn't know what a
  trackball is; it emits already-decoded `WaveEvent`s.
- **TIPCWireFormat** — big-endian integer/float/string encode-decode
  helpers plus the full command byte table, copied from `main.c` rather
  than re-derived. Floats specifically use main.c's exact (reversed-byte,
  not numeric-swap) layout — see the comment in `TIPCReader.readFloat()`
  if that ever looks wrong; it's intentional.
- **TIPCFraming** — splits the raw TCP stream into complete
  length-prefixed messages, then splits each message into one or more
  commands (a single message CAN carry multiple back-to-back commands —
  confirmed by `ParseReceived`'s loop in main.c). Isolated from socket
  lifecycle so this is unit-testable without a live Hub.
- **DeviceManager** — the published, `ObservableObject` source of truth
  for "what's the Wave doing right now." Bridges TIPCClient's event
  stream into app state, and turns a capabilities count into a concrete
  `[HardwareControl]` list using `WaveControlNaming`. This is the layer
  Palette will eventually extend with DCTL-parameter mapping (likely by
  switching to managed mode — see above) — everything below it should
  stay untouched by that work.
- **HardwareControl / WaveEvent** — plain value types. `WaveEvent` stays
  close to the wire (e.g. `encoderChanged`, not `trackballMoved`) on
  purpose — see "Managed vs unmanaged" above for why baking panel-specific
  interpretation into the event model would be a mistake this early.
- **WaveControlNaming** — the ONE place panel-specific physical layout
  knowledge lives. A different panel model gets its own naming table
  without touching TIPCClient, DeviceManager, or WaveEvent.
- **EventLogger** — a single `log(_:naming:)` entry point backed by
  `os.Logger` (survives crashes, filterable in Console.app, no file-handle
  management) plus a capped in-memory ring buffer that feeds the UI
  directly.
- **OLEDManager** — outbound label writes. Confirmed behavior (see its
  doc comment): in unmanaged mode this is request/response, not a free
  push — the Hub asks for a display refresh and you answer via
  `TIPCClient.displayTextProvider`. This resolves what the original spec
  flagged as an open "if supported by the SDK" question.
- **DebugView** — one flat window: Connection Status, Device Information,
  Detected Controls, Recent Events. No navigation hierarchy — this tool
  exists to be glanced at while turning a ring, not to be a product.

## Logging architecture

`EventLogger` writes every event through `os.Logger` as the durable sink,
and keeps a capped in-memory array (`recentEvents`) purely for the SwiftUI
list.

- `os.Logger` costs nothing to add, needs no rotation/cleanup code, and
  gives you a session's history in Console.app even after the app quits —
  valuable when a panel silently drops mid-session.
- The in-memory buffer is capped (`maxRecent`, default 200) so a busy
  trackball session doesn't grow an unbounded array behind the UI.
- If Palette later needs structured, replayable logs (e.g. automated
  regression testing against captured sessions), add a `.jsonl` file sink
  behind the same `log(_:)` call — no call site elsewhere needs to change.

## Pitfalls to plan around

1. **Managed vs. unmanaged is a one-way-feeling architectural choice.**
   Not literally irreversible, but the two modes shape your whole event
   model differently (abstract parameters vs. raw control numbers).
   Decide deliberately when Palette starts consuming `WaveExplorerCore` —
   don't let it inherit "unmanaged" by default just because that's what
   this bring-up tool used.

2. **The Hub must already be running, and it speaks first.** TIPCClient
   connects to a local TCP socket (port 64246) served by the Tangent Hub
   background process, then WAITS for `INITIATE_COMMS` before sending
   anything (confirmed in main.c — the app never initiates). If the Hub
   isn't running, that's a `.failed` connection state and a clear message
   to the user, not a retry loop that pretends the panel is the problem.

3. **TCP gives you a byte stream, not messages, and one message can hold
   several commands.** `TIPCFraming.extractMessages` handles the first
   part; `TIPCCommandDecoder`'s `while reader.bytesRemaining >= 4` loop
   handles the second. Both are confirmed necessary by main.c, not
   defensive over-engineering — rapid trackball movement is a good stress
   test for both.

4. **No official Swift/XCFramework SDK.** The Developer Support Pack is
   C headers + a sample mock application + XML docs, not a Swift package.
   This scaffold's wire layer is a clean-room Swift reimplementation of
   what `main.c` does, not a wrapper around Tangent's C code — if you'd
   rather link the real C library (if one ships in the pack you have),
   that changes `TIPCWireFormat`/`TIPCFraming` but shouldn't need to touch
   anything above `TIPCClient`.

5. **Unrecognized commands stop decoding the rest of that message.**
   `TIPCCommandDecoder` doesn't know the payload length of managed-mode
   commands it hasn't implemented (parameter/menu/action/mode traffic),
   so on an unknown command it logs `.unrecognized` and stops rather than
   guessing where the next command starts and potentially misparsing
   everything after it. If you switch to managed mode, those cases need
   implementing for exactly this reason.

6. **`WaveControlNaming` is a partial table, not documentation.** It's
   sourced from a sample map file, which only exercises trackball 1 and a
   handful of controls. Treat unnamed "Encoder N" / "Button N" entries in
   the Detected Controls list as expected, not a bug, until the table is
   filled in further.

7. **One connection at a time, and app identity matters.** Set
   `TIPCClient.applicationName` to something distinct per app. If
   WaveExplorer and a future Palette build both register with the same
   Hub, keep their app names different or expect confusion about which
   app owns the panel.

8. **Sandboxing/entitlements if this ever ships as a signed .app.** A
   sandboxed macOS app needs the outgoing-network-connection entitlement
   to open a socket at all. Not a concern for `swift run` during bring-up,
   but flag it before wrapping this in a distributable .app.

## What's deliberately not here

No Resolve integration, no DCTL awareness, no accessibility APIs, no
Palette UI, no managed-mode command decoding. If a change to this package
starts requiring any of those, it's scope creep for this milestone — that
work belongs in Palette, built on top of `WaveExplorerCore` once this
foundation is verified against a real Wave.
