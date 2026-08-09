import SwiftUI
import WaveExplorerCore

/// The entire UI deliverable for this milestone. Deliberately one flat
/// view with a few subviews rather than a navigation hierarchy — this is a
/// dev tool meant to be glanced at while wiggling a trackball, not a
/// product surface. Don't over-build this; Palette gets its own UI later.
struct DebugView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @EnvironmentObject private var logger: EventLogger

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                ConnectionStatusSection(deviceManager: deviceManager)
                Divider()
                DeviceInfoSection(deviceManager: deviceManager)
                Divider()
                MappingDiagnosticSection(deviceManager: deviceManager)
                Divider()
                DetectedControlsSection(controls: deviceManager.controls)
                Spacer()
            }
            .padding()
            .frame(minWidth: 280)

            RecentEventsSection(events: logger.recentEvents)
                .frame(minWidth: 360)
        }
        .frame(minWidth: 720, minHeight: 440)
        .onAppear { deviceManager.connect() }
    }
}

private struct MappingDiagnosticSection: View {
    @ObservedObject var deviceManager: DeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live Diagnostic").font(.headline)
            Text(deviceManager.mappingStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(deviceManager.lastEventSummary)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}

private struct ConnectionStatusSection: View {
    @ObservedObject var deviceManager: DeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connection Status").font(.headline)
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
            }
            HStack {
                Button("Connect") { deviceManager.connect() }
                Button("Disconnect") { deviceManager.disconnect() }
            }
        }
    }

    private var label: String {
        switch deviceManager.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected — waiting for Hub handshake"
        case .ready: return "Ready"
        case .failed(let reason): return "Failed: \(reason)"
        }
    }

    private var color: Color {
        switch deviceManager.connectionState {
        case .ready: return .green
        case .connected, .connecting: return .yellow
        case .disconnected: return .gray
        case .failed: return .red
        }
    }
}

private struct DeviceInfoSection: View {
    @ObservedObject var deviceManager: DeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Device Information").font(.headline)
            if let panelID = deviceManager.connectedPanelID {
                LabeledContent("Panel ID", value: "0x\(String(panelID, radix: 16))")
                Button("Write Test Label") {
                    deviceManager.writeTestLabel()
                }
                Text(deviceManager.lastOLEDWriteStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No panel connected").foregroundStyle(.secondary)
            }
            if let caps = deviceManager.capabilities {
                LabeledContent("Buttons", value: "\(caps.buttons)")
                LabeledContent("Encoders", value: "\(caps.encoders)")
                LabeledContent("Displays", value: "\(caps.displays) (\(caps.linesPerDisplay)×\(caps.charsPerLine))")
            }
        }
    }
}

private struct DetectedControlsSection: View {
    let controls: [HardwareControl]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Detected Controls").font(.headline)
            if controls.isEmpty {
                Text("None yet — waiting for panel capabilities").foregroundStyle(.secondary)
            } else {
                List(controls) { control in
                    HStack {
                        Text(control.displayName)
                        Spacer()
                        Text(control.kind.rawValue).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 160)
            }
        }
    }
}

private struct RecentEventsSection: View {
    let events: [EventLogger.LoggedEvent]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Events").font(.headline).padding([.top, .horizontal])
            List(events.reversed()) { event in
                Text(event.line).font(.system(.body, design: .monospaced))
            }
        }
    }
}
