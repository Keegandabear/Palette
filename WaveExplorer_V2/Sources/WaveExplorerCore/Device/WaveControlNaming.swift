import Foundation

/// Best-effort control-number -> friendly-name lookup for a Wave panel.
///
/// IMPORTANT — where these numbers came from: the entries marked "confirmed"
/// below are copied directly from the `wave-map.xml` sample map shipped in
/// the Developer Support Pack (a demo map for the mock app, not necessarily
/// Tangent's exhaustive physical reference). Physical verification fills in
/// the controls that the sample map omits.
///
/// This table is intentionally separate from `WaveEvent` and `DeviceManager`
/// — it's presentation-layer knowledge about ONE specific panel model, not
/// protocol behavior. A different panel (Element, Ripple) would get its own
/// `WaveControlNaming`-shaped table without touching anything else here.
public struct WaveControlNaming: Sendable {
    private let encoderNames: [Int: String]
    private let buttonNames: [Int: String]

    public init(encoderNames: [Int: String] = WaveControlNaming.knownEncoders,
                buttonNames: [Int: String] = WaveControlNaming.knownButtons) {
        self.encoderNames = encoderNames
        self.buttonNames = buttonNames
    }

    public func name(forEncoder number: Int) -> String? {
        encoderNames[number].map { "Encoder \(number) (\($0))" }
    }

    public func name(forButton number: Int) -> String? {
        buttonNames[number].map { "Button \(number) (\($0))" }
    }

    public static let wavePanelID = 0xA0001

    public static func isWavePanel(panelID: Int, displays: Int, linesPerDisplay: Int, charsPerLine: Int) -> Bool {
        panelID == wavePanelID || (displays == 3 && linesPerDisplay == 5 && charsPerLine == 32)
    }

    /// Encoder numbers 0–7 are the top knobs and are intentionally preserved.
    /// Wheel and trackball labels below include physical verification on the
    /// real Wave. Secondary trackball axis orientation stays Axis 1/2 until
    /// X/Y is confirmed with a directional test.
    public static let knownEncoders: [Int: String] = [
        0: "Knob 1",
        1: "Knob 2",
        2: "Knob 3",
        3: "Knob 4",
        4: "Knob 5",
        5: "Knob 6",
        6: "Knob 7",
        7: "Knob 8",
        9: "Wheel 1 / Trackball 1 Rotate",
        10: "Wheel 2",
        11: "Wheel 3",
        12: "Transport Dial",
        13: "Trackball 1 X",
        14: "Trackball 1 Y",
        15: "Trackball 2 Axis 1",
        16: "Trackball 2 Axis 2",
        17: "Trackball 3 Axis 1",
        18: "Trackball 3 Axis 2",
    ]

    public static let knownButtons: [Int: String] = [
        9: "Alt",
        10: "Button 1",
        11: "Button 2",
        12: "Button 3",
        20: "Button 7",
        21: "Button 8",
        22: "Button 9",
        30: "Function 4",
        31: "Function 5",
        33: "Function 1",
        34: "Function 2",
        35: "Function 3",
        25: "Up Arrow",
        26: "Down Arrow",
        36: "Inch Reverse",
        37: "Inch Forward",
        38: "Play Reverse",
        39: "Stop",
        40: "Play Forward",
    ]
}
