import Foundation

/// A decoded TIPC event. Cases and field names here are deliberately close
/// to the wire protocol (verified against Tangent's MockApplication
/// `main.c`) rather than pre-interpreted — e.g. a trackball move arrives
/// as an `encoderChanged` on a specific control number, same as a knob,
/// because that's genuinely how the protocol reports it. Turning
/// "Encoder 13" into "Trackball 1 X" is a display-layer concern (see
/// `WaveControlNaming`), not something the event model should bake in.
public enum WaveEvent: Sendable {
    /// Hub identified itself and told us its protocol revision. Sent
    /// alongside one `panelListed` per panel currently known to the hub.
    case hubReady(protocolRevision: Int)
    case panelListed(panelType: Int, panelID: Int)
    case panelConnectionChanged(panelID: Int, connected: Bool)

    /// Reply to our capabilities request — the closest thing this protocol
    /// has to "enumerate every control": counts per control class, not
    /// individual named controls. See README "What 'enumerate' actually means".
    case panelCapabilities(panelID: Int, buttons: Int, encoders: Int, displays: Int, linesPerDisplay: Int, charsPerLine: Int)

    /// Covers knobs, rings, and trackball axes alike — the protocol makes
    /// no distinction; `delta` is a float, not a step count.
    case encoderChanged(panelID: Int, controlNumber: Int, delta: Float)
    case buttonDown(panelID: Int, controlNumber: Int)
    case buttonUp(panelID: Int, controlNumber: Int)
    case transport(jog: Int, shuttle: Int)

    /// Hub asking us to (re)paint a panel's OLED — reply via `OLEDManager`.
    case displayRefreshRequested(panelID: Int)

    /// A command we don't decode in this milestone (managed-mode
    /// parameter/menu/action traffic, or something new). Kept instead of
    /// silently dropped so raw traffic is still visible during bring-up.
    case unrecognized(commandCode: UInt32, byteCount: Int)
}

extension WaveEvent {
    /// Human-readable form for the event log. Takes an optional naming
    /// lookup so known control numbers (e.g. "Encoder 13" = Trackball 1 X,
    /// per the sample wave-map.xml) show a friendly label without the
    /// event model itself needing to know panel layouts.
    public func logLine(naming: WaveControlNaming? = nil) -> String {
        switch self {
        case .hubReady(let revision):
            return "Hub Ready (protocol rev \(revision))"
        case .panelListed(let type, let id):
            return "Panel Listed — type \(type), id 0x\(String(id, radix: 16))"
        case .panelConnectionChanged(let id, let connected):
            return "Panel 0x\(String(id, radix: 16)) \(connected ? "Connected" : "Disconnected")"
        case .panelCapabilities(let id, let buttons, let encoders, let displays, let lines, let chars):
            return "Panel 0x\(String(id, radix: 16)) Capabilities — \(buttons) buttons, \(encoders) encoders, \(displays) displays (\(lines)×\(chars))"
        case .encoderChanged(_, let number, let delta):
            let label = naming?.name(forEncoder: number) ?? "Encoder \(number)"
            return "\(label) Delta \(signed(delta))"
        case .buttonDown(_, let number):
            return "\(naming?.name(forButton: number) ?? "Button \(number)") Pressed"
        case .buttonUp(_, let number):
            return "\(naming?.name(forButton: number) ?? "Button \(number)") Released"
        case .transport(let jog, let shuttle):
            return jog != 0 ? "Transport Jog \(signed(Float(jog)))" : "Transport Shuttle \(signed(Float(shuttle)))"
        case .displayRefreshRequested(let id):
            return "Display Refresh Requested (panel 0x\(String(id, radix: 16)))"
        case .unrecognized(let code, let bytes):
            return "Unrecognized command 0x\(String(code, radix: 16)) (\(bytes) bytes remaining)"
        }
    }

    private func signed(_ value: Float) -> String {
        value >= 0 ? String(format: "+%.3f", value) : String(format: "%.3f", value)
    }
}
