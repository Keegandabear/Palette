import Foundation

/// Extracts complete TIPC messages from a growing TCP receive buffer.
///
/// Confirmed against `ReadData()` in Tangent's MockApplication `main.c`:
/// each message on the wire is a 4-byte big-endian length prefix (the
/// length of what follows, NOT including these 4 bytes) followed by that
/// many payload bytes. A single message's payload can itself contain
/// MORE THAN ONE command back-to-back — the mock app's `ParseReceived`
/// loops over the payload consuming one 4-byte command code + its
/// fields at a time until the payload is exhausted. `TIPCFraming` only
/// handles the outer length-prefixed split; command-level splitting
/// happens in `TIPCCommandDecoder`.
enum TIPCFraming {
    /// Removes and returns every complete message currently sitting at the
    /// front of `buffer`. Leaves a trailing partial message (if any) in
    /// `buffer` for the next call — TCP reads don't respect message
    /// boundaries, so partial reads are the normal case, not an edge case.
    static func extractMessages(from buffer: inout Data) -> [Data] {
        var messages: [Data] = []

        while true {
            guard buffer.count >= 4 else { break }

            let start = buffer.startIndex
            let length = (UInt32(buffer[start]) << 24)
                | (UInt32(buffer[start + 1]) << 16)
                | (UInt32(buffer[start + 2]) << 8)
                | UInt32(buffer[start + 3])

            let totalNeeded = 4 + Int(length)
            guard buffer.count >= totalNeeded else { break } // wait for more bytes

            let payloadStart = start + 4
            let payload = buffer.subdata(in: payloadStart..<(payloadStart + Int(length)))
            messages.append(payload)

            buffer.removeSubrange(start..<(start + totalNeeded))
        }

        return messages
    }
}

/// Splits one message payload into its individual commands and decodes
/// each into a `WaveEvent`. Mirrors `ParseReceived`'s command loop in
/// main.c. Commands that need a protocol-level reply (not just an event
/// for the rest of the app) are surfaced via `HandshakeAction` so
/// `TIPCClient` can respond — decoding stays a pure function, sending
/// stays TIPCClient's job.
enum TIPCCommandDecoder {

    struct DecodedMessage {
        var events: [WaveEvent] = []
        var handshakeActions: [HandshakeAction] = []
    }

    enum HandshakeAction {
        /// Hub told us its protocol revision and current panel list —
        /// reply with our application definition, then (unmanaged mode)
        /// ask for capabilities on each panel.
        case sendApplicationDefinition(panelIDs: [UInt32])
        /// Hub wants the current display contents for a panel (unmanaged
        /// mode) — reply with an unmanaged display write.
        case sendDisplayRefresh(panelID: UInt32)
    }

    static func decode(_ message: Data) -> DecodedMessage {
        var result = DecodedMessage()
        var reader = TIPCReader(message)

        while reader.bytesRemaining >= 4 {
            guard let cmd = reader.readUInt32() else { break }

            switch cmd {
            case TIPCCommand.Hub.initiateComms:
                guard let revision = reader.readUInt32(),
                      let panelCount = reader.readUInt32() else { return result }
                var panelIDs: [UInt32] = []
                for _ in 0..<panelCount {
                    guard let panelType = reader.readUInt32(),
                          let panelID = reader.readUInt32() else { return result }
                    panelIDs.append(panelID)
                    result.events.append(.panelListed(panelType: Int(panelType), panelID: Int(panelID)))
                }
                result.events.append(.hubReady(protocolRevision: Int(revision)))
                result.handshakeActions.append(.sendApplicationDefinition(panelIDs: panelIDs))

            case TIPCCommand.Hub.unmanagedEncoderChange:
                guard let panelID = reader.readUInt32(),
                      let controlNumber = reader.readUInt32(),
                      let value = reader.readFloat() else { return result }
                result.events.append(.encoderChanged(panelID: Int(panelID), controlNumber: Int(controlNumber), delta: value))

            case TIPCCommand.Hub.unmanagedButtonDown:
                guard let panelID = reader.readUInt32(),
                      let controlNumber = reader.readUInt32() else { return result }
                result.events.append(.buttonDown(panelID: Int(panelID), controlNumber: Int(controlNumber)))

            case TIPCCommand.Hub.unmanagedButtonUp:
                guard let panelID = reader.readUInt32(),
                      let controlNumber = reader.readUInt32() else { return result }
                result.events.append(.buttonUp(panelID: Int(panelID), controlNumber: Int(controlNumber)))

            case TIPCCommand.Hub.unmanagedPanelCapabilities:
                guard let panelID = reader.readUInt32(),
                      let buttons = reader.readUInt32(),
                      let encoders = reader.readUInt32(),
                      let displays = reader.readUInt32(),
                      let lines = reader.readUInt32(),
                      let chars = reader.readUInt32() else { return result }
                result.events.append(.panelCapabilities(
                    panelID: Int(panelID), buttons: Int(buttons), encoders: Int(encoders),
                    displays: Int(displays), linesPerDisplay: Int(lines), charsPerLine: Int(chars)
                ))

            case TIPCCommand.Hub.unmanagedDisplayRefresh:
                guard let panelID = reader.readUInt32() else { return result }
                result.events.append(.displayRefreshRequested(panelID: Int(panelID)))
                result.handshakeActions.append(.sendDisplayRefresh(panelID: panelID))

            case TIPCCommand.Hub.panelConnectionState:
                guard let panelID = reader.readUInt32(),
                      let connected = reader.readUInt32() else { return result }
                result.events.append(.panelConnectionChanged(panelID: Int(panelID), connected: connected != 0))

            case TIPCCommand.Hub.transport:
                guard let jog = reader.readInt32(), let shuttle = reader.readInt32() else { return result }
                result.events.append(.transport(jog: Int(jog), shuttle: Int(shuttle)))

            default:
                // Managed-mode commands (parameter/menu/action/mode) and
                // custom-control variants aren't decoded in this milestone
                // — WaveExplorer runs unmanaged. See README "Managed vs
                // unmanaged" before adding these.
                result.events.append(.unrecognized(commandCode: cmd, byteCount: reader.bytesRemaining))
                return result // can't safely skip a command whose payload
                              // length we don't know how to parse — stop
                              // rather than misinterpret the rest as noise.
            }
        }

        return result
    }
}
