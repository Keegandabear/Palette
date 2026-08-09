import Foundation

/// Command byte values, verified directly against Tangent's `MockApplication`
/// `main.c` (Developer Support Pack). Do not renumber these — they are the
/// wire protocol, not an internal enum WaveExplorer is free to redefine.
public enum TIPCCommand {
    /// Hub -> App
    public enum Hub {
        public static let initiateComms: UInt32                       = 0x01
        public static let parameterChange: UInt32                     = 0x02
        public static let parameterReset: UInt32                      = 0x03
        public static let parameterValueRequest: UInt32                = 0x04
        public static let menuChange: UInt32                          = 0x05
        public static let menuReset: UInt32                           = 0x06
        public static let menuStringRequest: UInt32                    = 0x07
        public static let actionOn: UInt32                            = 0x08
        public static let modeChange: UInt32                          = 0x09
        public static let transport: UInt32                           = 0x0A
        public static let actionOff: UInt32                           = 0x0B
        public static let unmanagedPanelCapabilities: UInt32           = 0x30
        public static let unmanagedButtonDown: UInt32                  = 0x31
        public static let unmanagedButtonUp: UInt32                    = 0x32
        public static let unmanagedEncoderChange: UInt32               = 0x33
        public static let unmanagedDisplayRefresh: UInt32              = 0x34
        public static let panelConnectionState: UInt32                 = 0x35
        public static let trainControl: UInt32                        = 0x3E
        // Custom-control variants (0x36–0x3D) exist but aren't wired up
        // in this milestone — WaveExplorer doesn't author custom controls.
    }

    /// App -> Hub
    public enum App {
        public static let applicationDefinition: UInt32                = 0x81
        public static let parameterValue: UInt32                       = 0x82
        public static let menuString: UInt32                          = 0x83
        public static let allChange: UInt32                           = 0x84
        public static let modeValue: UInt32                           = 0x85
        public static let displayText: UInt32                         = 0x86
        public static let unmanagedPanelCapabilitiesRequest: UInt32     = 0xA0
        public static let unmanagedDisplayWrite: UInt32                = 0xA1
        public static let requestPanelConnectionStates: UInt32         = 0xA5
        public static let requestFocus: UInt32                        = 0xAB
        public static let releaseFocus: UInt32                        = 0xAC
    }
}

/// Reads Tangent's wire types out of a `Data` buffer. All integers are
/// big-endian (verified: `ReadInt32`/`WriteInt32` in main.c shift the first
/// byte read into bits 24–31). Floats use the same byte order, reconstructed
/// byte-for-byte rather than via a numeric shift (see `WriteFloat` in
/// main.c) — `readFloat` below matches that byte layout exactly.
struct TIPCReader {
    private let data: Data
    private(set) var offset: Int

    init(_ data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    var bytesRemaining: Int { data.count - offset }

    mutating func readUInt32() -> UInt32? {
        guard bytesRemaining >= 4 else { return nil }
        let b0 = UInt32(data[data.startIndex + offset])
        let b1 = UInt32(data[data.startIndex + offset + 1])
        let b2 = UInt32(data[data.startIndex + offset + 2])
        let b3 = UInt32(data[data.startIndex + offset + 3])
        offset += 4
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    mutating func readInt32() -> Int32? {
        guard let raw = readUInt32() else { return nil }
        return Int32(bitPattern: raw)
    }

    mutating func readFloat() -> Float? {
        guard bytesRemaining >= 4 else { return nil }
        // main.c's WriteFloat stores the float's raw bytes in REVERSED
        // order (byte 3, 2, 1, 0 of the native float) rather than doing a
        // numeric byte-order swap of a re-interpreted integer. Mirror that
        // exactly: read 4 bytes, reverse them, reinterpret as Float32.
        let b0 = data[data.startIndex + offset]
        let b1 = data[data.startIndex + offset + 1]
        let b2 = data[data.startIndex + offset + 2]
        let b3 = data[data.startIndex + offset + 3]
        offset += 4
        let reversed = Data([b3, b2, b1, b0])
        return reversed.withUnsafeBytes { $0.load(as: Float32.self) }
    }

    /// Tangent strings are a 4-byte big-endian length prefix followed by
    /// that many raw (non-terminated) bytes.
    mutating func readString() -> String? {
        guard let length = readUInt32(), bytesRemaining >= Int(length) else { return nil }
        let start = data.startIndex + offset
        let sub = data.subdata(in: start..<(start + Int(length)))
        offset += Int(length)
        return String(data: sub, encoding: .utf8)
    }
}

struct TIPCWriter {
    private(set) var data = Data()

    mutating func writeUInt32(_ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    mutating func writeInt32(_ value: Int32) {
        writeUInt32(UInt32(bitPattern: value))
    }

    mutating func writeString(_ string: String) {
        let bytes = Array(string.utf8)
        writeUInt32(UInt32(bytes.count))
        data.append(contentsOf: bytes)
    }

    mutating func writeDisplayString(_ string: String) {
        writeString(string)
    }

    mutating func writeInvertedDisplayString(_ string: String) {
        let bytes = Array(string.utf8)
        writeUInt32(UInt32(bytes.count))
        data.append(contentsOf: bytes)
        if !bytes.isEmpty {
            data[data.index(before: data.endIndex)] |= 0x80
        }
    }

    /// Wraps this writer's accumulated command bytes in the outer 4-byte
    /// big-endian length prefix TIPC expects on every message sent to the
    /// Hub (length excludes the prefix itself — confirmed in main.c's
    /// `Send()`/`ReadData()`).
    func framed() -> Data {
        var framer = TIPCWriter()
        framer.writeUInt32(UInt32(data.count))
        return framer.data + data
    }
}
