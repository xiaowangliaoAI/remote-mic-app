// SPDX-License-Identifier: GPL-3.0-only
// Adapted from zfdang/voice-input-buddy, commit
// f51f5c800e6de9e2e9a55be61744c9a40797128b:
// Devices/G9N9NProtocol.swift and RemoteHIDIdentity.swift.
// See THIRD_PARTY_NOTICES.md for source and attribution.
import Foundation

enum G9N9NProtocol {
    // Names nominate candidates; only the same peripheral's PnP ID plus
    // its negotiated ATVV capabilities allow the voice transport to run.
    static func isCandidateName(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return ["chromecast", "chromecast remote", "chromecast voice remote",
                "chromecast 遥控器", "g9n9n", "小米遥控器"].contains(name)
    }

    static func matchesIdentity(_ data: Data) -> Bool {
        let bytes = Array(data)
        guard bytes.count == 7, bytes[0] == 1 || bytes[0] == 2 else { return false }
        let vendor = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
        let product = UInt16(bytes[3]) | UInt16(bytes[4]) << 8
        return vendor == 0x18D1 && product == 0x9450
    }

    static func acceptsCapabilities(_ caps: ATVVCapabilities) -> Bool {
        caps.version == 0x0100 && caps.codecs & 0x02 != 0 &&
            caps.selectedCodec == 0x02 && caps.sampleRate == 16_000 &&
            (1...512).contains(caps.frameSize)
    }

    static func acceptsStreamStart(_ data: Data) -> Bool {
        data.count >= 4 && data[data.startIndex] == 0x04 && data[data.startIndex + 2] == 0x02
    }
}

struct G9N9NReadiness {
    private(set) var identityConfirmed = false
    private(set) var audioConfirmed = false
    var isReady: Bool { identityConfirmed && audioConfirmed }

    @discardableResult mutating func acceptIdentity(_ data: Data) -> Bool {
        identityConfirmed = G9N9NProtocol.matchesIdentity(data)
        return identityConfirmed
    }
    @discardableResult mutating func acceptCapabilities(_ caps: ATVVCapabilities) -> Bool {
        audioConfirmed = G9N9NProtocol.acceptsCapabilities(caps)
        return audioConfirmed
    }
}
