import Foundation

/// The single source of truth for "what is the Wave doing right now."
///
/// Why this class exists, distinct from TIPCClient:
/// TIPCClient's job ends at "here is a decoded WaveEvent" (plus the
/// protocol-mandated handshake replies it must send on its own). This
/// job is to accumulate those events into meaningful state — is a panel
/// connected, what did it say its capabilities are, what controls should
/// the UI show — and publish that state to SwiftUI. This is also the
/// layer Palette will eventually extend with real DCTL-parameter mapping;
/// keeping it separate from the socket code means that future work never
/// has to touch TIPCClient.
///
/// Assumes a single connected panel for this milestone (the common case:
/// one Wave). Multi-panel support is a straightforward generalization —
/// keyed dictionaries instead of single `@Published` values — deliberately
/// deferred to keep this milestone's scope small.
@MainActor
public final class DeviceManager: ObservableObject {

    @Published public private(set) var connectionState: TIPCClient.ConnectionState = .disconnected
    @Published public private(set) var connectedPanelID: Int?
    @Published public private(set) var capabilities: PanelCapabilities?
    @Published public private(set) var controls: [HardwareControl] = []
    @Published public private(set) var lastOLEDWriteStatus = "No OLED write sent yet"
    @Published public private(set) var lastEventSummary = "No hardware event yet"
    @Published public private(set) var mappingStatus = "Waiting for panel capabilities"

    public struct PanelCapabilities: Sendable {
        public let buttons: Int
        public let encoders: Int
        public let displays: Int
        public let linesPerDisplay: Int
        public let charsPerLine: Int
    }

    private let client: TIPCClient
    private let logger: EventLogger
    private let oledManager: OLEDManager
    private var panelCapabilitiesByID: [Int: PanelCapabilities] = [:]
    /// Panel-specific control naming. Defaults to the Wave table since
    /// that's the only panel this milestone targets — swap this per
    /// connected panel type once WaveExplorer needs to support more than
    /// one panel model.
    public var naming = WaveControlNaming()

    public init(client: TIPCClient = TIPCClient(), logger: EventLogger) {
        self.client = client
        self.logger = logger
        self.oledManager = OLEDManager(client: client)

        client.onStateChange = { [weak self] state in
            Task { @MainActor in self?.connectionState = state }
        }
        client.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
    }

    public func connect() {
        client.connect()
    }

    public func disconnect() {
        client.disconnect()
        connectedPanelID = nil
        capabilities = nil
        controls = []
        panelCapabilitiesByID.removeAll()
        lastOLEDWriteStatus = "No OLED write sent yet"
        lastEventSummary = "No hardware event yet"
        mappingStatus = "Waiting for panel capabilities"
    }

    public func writeTestLabel() {
        let displayPanels = panelCapabilitiesByID
            .filter { $0.value.displays > 0 }
            .sorted { $0.key < $1.key }

        guard !displayPanels.isEmpty else {
            lastOLEDWriteStatus = "No display-bearing panel found"
            return
        }

        let waveDisplayPanels = displayPanels.filter {
            $0.value.displays == 3 &&
            $0.value.linesPerDisplay == 5 &&
            $0.value.charsPerLine == 32
        }
        let targetPanels = waveDisplayPanels.isEmpty ? displayPanels : waveDisplayPanels

        var writes = 0
        for (panelID, panelCaps) in targetPanels {
            for displayNumber in 0..<panelCaps.displays {
                oledManager.setLabel(
                    "Wave Explorer",
                    panelID: UInt32(panelID),
                    displayNumber: UInt32(displayNumber)
                )
                writes += 1
            }
        }
        let panelSummary = targetPanels
            .map { "0x\(String($0.key, radix: 16)) (\($0.value.displays))" }
            .joined(separator: ", ")
        lastOLEDWriteStatus = "Queued \(writes) OLED writes to \(panelSummary); reconnecting for Hub refresh…"
        client.disconnect()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.client.connect()
        }
    }

    private func handle(_ event: WaveEvent) {
        let eventNaming = naming(for: event)
        logger.log(event, naming: eventNaming)
        lastEventSummary = event.logLine(naming: eventNaming)

        switch event {
        case .panelListed(_, let panelID):
            connectedPanelID = panelID

        case .panelConnectionChanged(let panelID, let connected):
            if connected {
                connectedPanelID = panelID
            } else if connectedPanelID == panelID {
                connectedPanelID = nil
                capabilities = nil
                controls = []
            }

        case .panelCapabilities(let panelID, let buttons, let encoders, let displays, let lines, let chars):
            let caps = PanelCapabilities(buttons: buttons, encoders: encoders, displays: displays, linesPerDisplay: lines, charsPerLine: chars)
            capabilities = caps
            let panelNaming = naming(for: panelID, capabilities: caps)
            controls = Self.buildControlList(from: caps, naming: panelNaming)
            panelCapabilitiesByID[panelID] = caps
            mappingStatus = panelNaming == nil
                ? "Generic numbering — panel 0x\(String(panelID, radix: 16))"
                : "Wave mapping active — panel 0x\(String(panelID, radix: 16))"

        case .hubReady, .encoderChanged, .buttonDown, .buttonUp, .transport,
             .displayRefreshRequested, .unrecognized:
            break // logged above; no further state to update in this milestone
        }
    }

    /// Builds the "Detected Controls" list from the counts the Hub reports
    /// plus whatever friendly names `naming` happens to know. Controls
    /// outside the known-name table still show up, just as "Encoder N" /
    /// "Button N" — the list length always matches what the Hub said it
    /// has, even where we can't yet say what a given number physically is.
    private static func buildControlList(from caps: PanelCapabilities, naming: WaveControlNaming?) -> [HardwareControl] {
        var result: [HardwareControl] = []
        for i in 0..<caps.encoders {
            let name = naming?.name(forEncoder: i) ?? "Encoder \(i)"
            result.append(HardwareControl(id: i, kind: .encoder, displayName: name))
        }
        for i in 0..<caps.buttons {
            let name = naming?.name(forButton: i) ?? "Button \(i)"
            result.append(HardwareControl(id: i, kind: .button, displayName: name))
        }
        for i in 0..<caps.displays {
            result.append(HardwareControl(id: i, kind: .oledDisplay, displayName: "Display \(i)"))
        }
        return result
    }

    private func naming(for panelID: Int, capabilities: PanelCapabilities? = nil) -> WaveControlNaming? {
        if let capabilities {
            return WaveControlNaming.isWavePanel(
                panelID: panelID,
                displays: capabilities.displays,
                linesPerDisplay: capabilities.linesPerDisplay,
                charsPerLine: capabilities.charsPerLine
            ) ? naming : nil
        }

        return panelCapabilitiesByID[panelID].flatMap { caps in
            naming(for: panelID, capabilities: caps)
        }
    }

    private func naming(for event: WaveEvent) -> WaveControlNaming? {
        switch event {
        case .encoderChanged(let panelID, _, _), .buttonDown(let panelID, _), .buttonUp(let panelID, _), .displayRefreshRequested(let panelID):
            return naming(for: panelID)
        case .hubReady, .panelListed, .panelConnectionChanged, .panelCapabilities, .transport, .unrecognized:
            return nil
        }
    }
}
