import SwiftUI
import WaveExplorerCore

@main
struct WaveExplorerApp: App {
    // Owns the object graph for the whole app. This is intentionally the
    // ONLY place these get constructed — DebugView receives them, it
    // doesn't build them, so the view stays testable/previewable.
    @StateObject private var logger: EventLogger
    @StateObject private var deviceManager: DeviceManager

    init() {
        let logger = EventLogger()
        _logger = StateObject(wrappedValue: logger)
        _deviceManager = StateObject(wrappedValue: DeviceManager(logger: logger))
    }

    var body: some Scene {
        WindowGroup("Wave Explorer") {
            DebugView()
                .environmentObject(deviceManager)
                .environmentObject(logger)
        }
    }
}
