import Foundation
import Network

/// Owns the raw TCP connection to the Tangent Hub (TUBE) background
/// process, plus just enough of the handshake to be a valid TIPC client —
/// nothing about what a trackball or button *means*.
///
/// Why this class exists:
/// TIPC is a plain TCP socket protocol — the Hub listens locally on
/// port 64246 and speaks Tangent's binary framing over it (confirmed
/// against the MockApplication `main.c` in the Developer Support Pack).
/// That's a fundamentally different layer of concern from "what does a
/// trackball event mean" (DeviceManager) or "how do I show this on screen"
/// (DebugView). Isolating socket lifecycle + framing + the mandatory
/// handshake here means DeviceManager never touches Network.framework or
/// worries about responding to the Hub correctly.
///
/// WaveExplorer runs the Hub in **unmanaged mode** — see README "Managed vs
/// unmanaged" for why. That means: no Controls.xml/wave-map.xml is required
/// to get raw button/encoder/capabilities traffic, at the cost of the Hub
/// only giving us control *numbers*, not names (see `WaveControlNaming`
/// for the display-layer fix-up).
public final class TIPCClient {

    public enum ConnectionState: Equatable, Sendable {
        case disconnected
        case connecting
        case connected      // TCP connected, waiting for the Hub's handshake
        case ready          // handshake complete, application definition sent
        case failed(String)
    }

    /// Confirmed in main.c: `#define IPC_SOCKET_PORT_NUMBER 64246`.
    public static let defaultPort: UInt16 = 64246

    /// Identifies WaveExplorer to the Hub. Must be unique among apps
    /// talking to the same Hub — see README pitfall on app identity.
    public var applicationName: String = "WaveExplorer"

    public private(set) var state: ConnectionState = .disconnected {
        didSet { onStateChange?(state) }
    }

    public var onEvent: ((WaveEvent) -> Void)?
    public var onStateChange: ((ConnectionState) -> Void)?

    /// Asked whenever the Hub requests a display refresh for a panel.
    /// `OLEDManager` sets this so a refresh replays whatever label was
    /// last set, instead of TIPCClient blanking the display by default.
    public var displayTextProvider: ((_ panelID: UInt32, _ displayNumber: UInt32, _ line: UInt32) -> String)?
    public struct DisplayWrite: Sendable {
        public let displayNumber: UInt32
        public let line: UInt32
        public let startPosition: UInt32
        public let text: String

        public init(displayNumber: UInt32, line: UInt32, startPosition: UInt32 = 0, text: String) {
            self.displayNumber = displayNumber
            self.line = line
            self.startPosition = startPosition
            self.text = text
        }
    }

    public var displayWritesProvider: ((_ panelID: UInt32) -> [DisplayWrite])?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.palette.waveexplorer.tipc")
    private var receiveBuffer = Data()

    public init() {}

    public func connect(host: NWEndpoint.Host = "127.0.0.1", port: UInt16 = TIPCClient.defaultPort) {
        state = .connecting
        let conn = NWConnection(host: host, port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        connection = conn

        conn.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                // TCP is up. We do NOT send anything yet — per main.c,
                // the Hub speaks first (IPC_HUB_COMMAND_INITIATE_COMMS).
                self.state = .connected
                self.receiveLoop()
            case .failed(let error):
                self.state = .failed(error.localizedDescription)
            case .cancelled:
                self.state = .disconnected
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
        receiveBuffer.removeAll()
    }

    // MARK: - Outbound commands

    /// Unmanaged-mode application definition: empty sys/usr dir paths,
    /// exactly as `SendApplicationDefinition` does in main.c when run with
    /// `-unmanaged`. A managed-mode client would send real paths to its
    /// Controls.xml/*-map.xml here instead — WaveExplorer deliberately
    /// doesn't, see README.
    private func sendApplicationDefinition() {
        var writer = TIPCWriter()
        writer.writeUInt32(TIPCCommand.App.applicationDefinition)
        writer.writeString(applicationName)
        writer.writeString("") // sys dir — empty = unmanaged
        writer.writeString("") // usr dir
        send(writer)
    }

    private func sendUnmanagedCapabilitiesRequest(panelIDs: [UInt32]) {
        var writer = TIPCWriter()
        for panelID in panelIDs {
            writer.writeUInt32(TIPCCommand.App.unmanagedPanelCapabilitiesRequest)
            writer.writeUInt32(panelID)
        }
        send(writer)
    }

    /// Responds to a display-refresh request. `text` should already be
    /// sized to the panel's line/char capacity (from `panelCapabilities`) —
    /// this method doesn't truncate or pad for you.
    public func sendDisplayWrite(panelID: UInt32, displayNumber: UInt32 = 0, line: UInt32 = 0, startPosition: UInt32 = 0, text: String) {
        sendDisplayWrites(panelID: panelID, writes: [DisplayWrite(displayNumber: displayNumber, line: line, startPosition: startPosition, text: text)])
    }

    public func sendDisplayWrites(panelID: UInt32, writes: [DisplayWrite]) {
        var writer = TIPCWriter()
        for write in writes {
            writer.writeUInt32(TIPCCommand.App.unmanagedDisplayWrite)
            writer.writeUInt32(panelID)
            writer.writeUInt32(write.displayNumber)
            writer.writeUInt32(write.line)
            writer.writeUInt32(write.startPosition)
            writer.writeDisplayString(write.text)
        }
        send(writer)
    }

    private func send(_ writer: TIPCWriter) {
        guard let connection else { return }
        connection.send(content: writer.framed(), completion: .contentProcessed { _ in })
    }

    // MARK: - Inbound

    /// Continuously reads from the socket, appends to `receiveBuffer`, and
    /// drains as many complete messages as are available. TCP gives us a
    /// byte stream, not message boundaries — `TIPCFraming` handles the
    /// buffering this requires; don't assume one `receive` call == one
    /// message (rapid trackball movement is a good stress test for this).
    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.receiveBuffer.append(data)
                for message in TIPCFraming.extractMessages(from: &self.receiveBuffer) {
                    self.handle(message)
                }
            }

            if let error {
                self.state = .failed(error.localizedDescription)
                return
            }
            if isComplete {
                self.state = .disconnected
                return
            }
            self.receiveLoop()
        }
    }

    private func handle(_ message: Data) {
        let decoded = TIPCCommandDecoder.decode(message)

        for event in decoded.events {
            onEvent?(event)
        }

        for action in decoded.handshakeActions {
            switch action {
            case .sendApplicationDefinition(let panelIDs):
                sendApplicationDefinition()
                sendUnmanagedCapabilitiesRequest(panelIDs: panelIDs)
                state = .ready
            case .sendDisplayRefresh(let panelID):
                if let writes = displayWritesProvider?(panelID), !writes.isEmpty {
                    sendDisplayWrites(panelID: panelID, writes: writes)
                } else {
                    let text = displayTextProvider?(panelID, 0, 0) ?? ""
                    sendDisplayWrite(panelID: panelID, text: text)
                }
            }
        }
    }
}
