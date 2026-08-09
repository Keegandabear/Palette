import Foundation

/// The kind of a control, as reported by the Hub's unmanaged-mode
/// capabilities response (buttons/encoders/displays counts — see
/// `IPC_HUB_COMMAND_UNMANAGED_PANEL_CAPABILITIES` in TIPCWireFormat).
/// There is no separate "trackball" or "ring" wire-level kind — physically
/// those are just encoder control numbers (confirmed: the sample
/// wave-map.xml maps "Wave Trackerball 1 X/Y" to Encoder numbers 13/14).
/// `WaveControlNaming` is what turns a bare encoder number into a
/// human-meaningful label; `ControlKind` stays true to the wire.
public enum ControlKind: String, Codable, CaseIterable, Sendable {
    case encoder
    case button
    case oledDisplay
}

/// A single addressable control on the panel, as counted by the Hub's
/// capabilities response for the connected panel.
public struct HardwareControl: Identifiable, Codable, Hashable, Sendable {
    /// Composite so encoder 0 and button 0 (both legitimately numbered "0"
    /// on the wire) don't collide as SwiftUI list identities.
    public var id: String { "\(kind.rawValue)-\(controlNumber)" }
    /// Tangent's control number for this element, as reported over TIPC —
    /// NOT an ID we assign; this is what shows up in raw event traffic.
    public let controlNumber: Int
    public let kind: ControlKind
    /// Human-readable name — from `WaveControlNaming` when known (e.g.
    /// "Encoder 13 (Trackball 1 X)"), otherwise a bare "Encoder 13".
    public let displayName: String
    /// Only meaningful for .oledDisplay controls: the current label text,
    /// if WaveExplorer has set one.
    public var currentLabel: String?

    public init(id controlNumber: Int, kind: ControlKind, displayName: String, currentLabel: String? = nil) {
        self.controlNumber = controlNumber
        self.kind = kind
        self.displayName = displayName
        self.currentLabel = currentLabel
    }
}
