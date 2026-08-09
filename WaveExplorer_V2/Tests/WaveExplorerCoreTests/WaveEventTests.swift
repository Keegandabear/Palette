import XCTest
@testable import WaveExplorerCore

final class WaveEventTests: XCTestCase {
    func testEncoderChangedLogLineWithoutNaming() {
        let event = WaveEvent.encoderChanged(panelID: 1, controlNumber: 3, delta: 2)
        XCTAssertEqual(event.logLine(), "Encoder 3 Delta +2.000")
    }

    func testEncoderChangedLogLineWithNaming() {
        let event = WaveEvent.encoderChanged(panelID: 1, controlNumber: 13, delta: 4)
        XCTAssertEqual(event.logLine(naming: WaveControlNaming()), "Encoder 13 (Trackball 1 X) Delta +4.000")
    }

    func testButtonPressedLogLine() {
        let event = WaveEvent.buttonDown(panelID: 1, controlNumber: 17)
        XCTAssertEqual(event.logLine(), "Button 17 Pressed")
    }

    func testWaveNamingIncludesSampleMapControls() {
        let naming = WaveControlNaming()

        XCTAssertEqual(naming.name(forEncoder: 7), "Encoder 7 (Knob 8)")
        XCTAssertEqual(naming.name(forEncoder: 14), "Encoder 14 (Trackball 1 Y)")
        XCTAssertEqual(naming.name(forButton: 33), "Button 33 (Function 1)")
        XCTAssertEqual(naming.name(forButton: 40), "Button 40 (Play Forward)")
    }

    func testFinalPhysicallyVerifiedWheelAndTrackballMappings() {
        let naming = WaveControlNaming()

        XCTAssertEqual(naming.name(forEncoder: 9), "Encoder 9 (Trackball 1 Rotate)")
        XCTAssertEqual(naming.name(forEncoder: 10), "Encoder 10 (Trackball 2 Rotate)")
        XCTAssertEqual(naming.name(forEncoder: 11), "Encoder 11 (Trackball 3 Rotate)")
        XCTAssertEqual(naming.name(forEncoder: 12), "Encoder 12 (Transport Dial)")
        XCTAssertEqual(naming.name(forEncoder: 13), "Encoder 13 (Trackball 1 X)")
        XCTAssertEqual(naming.name(forEncoder: 14), "Encoder 14 (Trackball 1 Y)")
        XCTAssertEqual(naming.name(forEncoder: 15), "Encoder 15 (Trackball 2 X)")
        XCTAssertEqual(naming.name(forEncoder: 16), "Encoder 16 (Trackball 2 Y)")
        XCTAssertEqual(naming.name(forEncoder: 17), "Encoder 17 (Trackball 3 X)")
        XCTAssertEqual(naming.name(forEncoder: 18), "Encoder 18 (Trackball 3 Y)")
    }

    func testWavePanelRecognitionUsesKnownIdentityOrDisplayShape() {
        XCTAssertTrue(WaveControlNaming.isWavePanel(panelID: 0xA0001, displays: 1, linesPerDisplay: 1, charsPerLine: 1))
        XCTAssertTrue(WaveControlNaming.isWavePanel(panelID: 123, displays: 3, linesPerDisplay: 5, charsPerLine: 32))
        XCTAssertFalse(WaveControlNaming.isWavePanel(panelID: 123, displays: 1, linesPerDisplay: 1, charsPerLine: 1))
    }
}

final class TIPCWireFormatTests: XCTestCase {
    func testFramingRoundTrip() {
        var writer = TIPCWriter()
        writer.writeUInt32(TIPCCommand.App.requestFocus)
        let framed = writer.framed()

        var buffer = framed
        let messages = TIPCFraming.extractMessages(from: &buffer)

        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(buffer.isEmpty)

        var reader = TIPCReader(messages[0])
        XCTAssertEqual(reader.readUInt32(), TIPCCommand.App.requestFocus)
    }

    func testFramingWaitsForPartialMessage() {
        var writer = TIPCWriter()
        writer.writeUInt32(TIPCCommand.App.requestFocus)
        let framed = writer.framed()

        // Simulate a TCP read that only delivered the first 3 bytes.
        var buffer = framed.prefix(3)
        let messages = TIPCFraming.extractMessages(from: &buffer)

        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(buffer.count, 3)
    }

    func testDecodeUnmanagedButtonDown() {
        var writer = TIPCWriter()
        writer.writeUInt32(TIPCCommand.Hub.unmanagedButtonDown)
        writer.writeUInt32(0x0000_1234) // panel id
        writer.writeUInt32(17)          // control number

        let decoded = TIPCCommandDecoder.decode(writer.data)
        XCTAssertEqual(decoded.events.count, 1)
        if case .buttonDown(let panelID, let controlNumber) = decoded.events[0] {
            XCTAssertEqual(panelID, 0x1234)
            XCTAssertEqual(controlNumber, 17)
        } else {
            XCTFail("expected .buttonDown")
        }
    }

    func testDisplayStringKeepsNormalTextUninverted() {
        var writer = TIPCWriter()
        writer.writeDisplayString("Hello!")

        XCTAssertEqual(writer.data.prefix(4), Data([0, 0, 0, 6]))
        XCTAssertEqual(writer.data.suffix(6), Data([72, 101, 108, 108, 111, 33]))
    }

    func testInvertedDisplayStringMarksLastByte() {
        var writer = TIPCWriter()
        writer.writeInvertedDisplayString("Hello!")

        XCTAssertEqual(writer.data.suffix(6), Data([72, 101, 108, 108, 111, 0xA1]))
    }
}
