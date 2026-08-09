import Foundation

/// Sends label text for a panel's OLED displays.
///
/// Why this is separate from DeviceManager: setting a label is an outbound
/// command (app -> Hub -> panel), while everything else DeviceManager
/// handles is inbound (panel -> Hub -> app). Keeping outbound commands in
/// their own small class means DeviceManager's job stays "reflect what the
/// hardware is doing" and doesn't grow a mixed read/write responsibility.
///
/// CONFIRMED against main.c (this resolves the "if supported by the SDK"
/// open question from the original spec): in unmanaged mode, display
/// writes are answers to the Hub's `IPC_HUB_COMMAND_UNMANAGED_DISPLAY_REFRESH`
/// request, sent via `IPC_APP_COMMAND_UNMANAGED_DISPLAY_WRITE` — you don't
/// get to push a label whenever you feel like it, the Hub asks and you
/// answer. `setLabel` both writes immediately AND remembers the text via
/// `TIPCClient.displayTextProvider`, so the NEXT unprompted refresh request
/// replays it instead of `TIPCClient` blanking the display. (Managed mode
/// has a genuinely push-style `IPC_APP_COMMAND_DISPLAY_TEXT` instead — out
/// of scope here since WaveExplorer runs unmanaged.)
public final class OLEDManager {
    private struct DisplayAddress: Hashable {
        let panelID: UInt32
        let displayNumber: UInt32
        let line: UInt32
    }

    private let client: TIPCClient
    private let lock = NSLock()
    /// `displayTextProvider` is invoked from TIPCClient's socket queue
    /// (background thread), while `setLabel` is typically called from the
    /// UI. The lock is here because of that, not out of caution for its
    /// own sake — a plain dictionary mutated from two threads is a real
    /// data race, not a theoretical one.
    private var pendingLabels: [DisplayAddress: String] = [:]

    public init(client: TIPCClient) {
        self.client = client
        client.displayTextProvider = { [weak self] panelID, displayNumber, displayLine in
            guard let self else { return "" }
            self.lock.lock()
            defer { self.lock.unlock() }
            let address = DisplayAddress(panelID: panelID, displayNumber: displayNumber, line: displayLine)
            return self.pendingLabels[address] ?? ""
        }
        client.displayWritesProvider = { [weak self] panelID in
            self?.writes(for: panelID) ?? []
        }
    }

    /// Sets a panel's display text and writes it immediately.
    public func setLabel(_ text: String, panelID: UInt32, displayNumber: UInt32 = 0, line: UInt32 = 0) {
        lock.lock()
        let address = DisplayAddress(panelID: panelID, displayNumber: displayNumber, line: line)
        pendingLabels[address] = text
        lock.unlock()
        client.sendDisplayWrite(panelID: panelID, displayNumber: displayNumber, line: line, text: text)
    }

    private func writes(for panelID: UInt32) -> [TIPCClient.DisplayWrite] {
        lock.lock()
        defer { lock.unlock() }
        return pendingLabels
            .filter { $0.key.panelID == panelID }
            .sorted {
                if $0.key.displayNumber != $1.key.displayNumber {
                    return $0.key.displayNumber < $1.key.displayNumber
                }
                return $0.key.line < $1.key.line
            }
            .map { entry in
                TIPCClient.DisplayWrite(
                    displayNumber: entry.key.displayNumber,
                    line: entry.key.line,
                    text: entry.value
                )
            }
    }
}
