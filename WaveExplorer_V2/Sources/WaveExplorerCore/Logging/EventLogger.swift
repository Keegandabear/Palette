import Foundation
import os

/// Records every WaveEvent, both for the on-screen "Recent Events" list and
/// for a durable trail you can inspect after the fact.
///
/// Why this is its own class instead of DeviceManager just appending to an
/// array: bring-up on a new SDK is exactly the situation where you want
/// logging that outlives the running process (panel drops out, app crashes,
/// you want to diff two sessions) and that doesn't block the event thread.
/// Separating it also means DebugView can be handed an EventLogger and stay
/// dumb — it never touches TIPCClient or DeviceManager directly.
///
/// Logging architecture:
///   - `os.Logger` (unified logging) is the sink of record. It's free,
///     survives app termination, is filterable in Console.app by subsystem,
///     and doesn't require us to manage file handles or rotation ourselves.
///   - A small in-memory ring buffer feeds the UI directly, so the debug
///     window doesn't re-read from the log store on every event.
///   - If Palette later needs structured (not just string) logs for replay
///     or automated testing, add a `.jsonl` file sink behind the same
///     `log(_:)` entry point — call sites elsewhere don't need to change.
@MainActor
public final class EventLogger: ObservableObject {
    private let osLog = Logger(subsystem: "com.palette.waveexplorer", category: "tipc-events")
    private let maxRecent: Int

    @Published public private(set) var recentEvents: [LoggedEvent] = []

    public struct LoggedEvent: Identifiable, Sendable {
        public let id = UUID()
        public let timestamp: Date
        public let line: String
    }

    public init(maxRecent: Int = 200) {
        self.maxRecent = maxRecent
    }

    /// `naming` is optional and purely cosmetic — pass it when you have a
    /// panel-specific lookup (see `WaveControlNaming`) so the log reads
    /// "Encoder 13 (Trackball 1 X)" instead of just "Encoder 13". The raw
    /// event itself is unaffected either way.
    public func log(_ event: WaveEvent, naming: WaveControlNaming? = nil) {
        let line = event.logLine(naming: naming)
        osLog.info("\(line, privacy: .public)")

        let entry = LoggedEvent(timestamp: Date(), line: line)
        recentEvents.append(entry)
        if recentEvents.count > maxRecent {
            recentEvents.removeFirst(recentEvents.count - maxRecent)
        }
    }
}
