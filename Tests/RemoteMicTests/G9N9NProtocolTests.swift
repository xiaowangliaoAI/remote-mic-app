// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Testing
@testable import RemoteMic

@Suite("Public G9N9N protocol boundary")
struct G9N9NProtocolTests {
    private let identity = Data([2, 0xD1, 0x18, 0x50, 0x94, 0, 0])
    private let caps = Data([0x0B, 1, 0, 2, 3, 0, 160])

    @Test func bothDiscoveryOrdersRequireIdentityAndAudio() throws {
        let parsed = try #require(ATVVCapabilities.parse(caps, allowingLegacyLayout: false))
        var identityFirst = G9N9NReadiness()
        #expect(identityFirst.acceptIdentity(identity))
        #expect(!identityFirst.isReady)
        #expect(identityFirst.acceptCapabilities(parsed))
        #expect(identityFirst.isReady)
        var audioFirst = G9N9NReadiness()
        #expect(audioFirst.acceptCapabilities(parsed))
        #expect(!audioFirst.isReady)
        #expect(audioFirst.acceptIdentity(identity))
        #expect(audioFirst.isReady)
        #expect(!audioFirst.acceptIdentity(Data([2, 0x17, 0x27, 0xB8, 0x32, 0, 0])))
        #expect(!audioFirst.isReady)
    }

    @Test func invalidIdentityAndEightKHzNeverBecomeReady() throws {
        var ready = G9N9NReadiness()
        #expect(!ready.acceptIdentity(identity.prefix(5)))
        #expect(ready.acceptIdentity(identity))
        let eightKHz = try #require(ATVVCapabilities.parse(Data([0x0B, 1, 0, 1, 3, 0, 160])))
        #expect(!ready.acceptCapabilities(eightKHz))
        #expect(!ready.isReady)
        let oversized = try #require(ATVVCapabilities.parse(Data([0x0B, 1, 0, 2, 3, 2, 1])))
        #expect(!ready.acceptCapabilities(oversized))
    }

    @Test func googleDoesNotUseXiaomiLegacyCapabilityFallback() throws {
        let legacy = Data([0x0B, 1, 0, 0, 2, 0, 160, 0, 0])
        #expect(try #require(ATVVCapabilities.parse(legacy)).sampleRate == 16_000)
        let strict = try #require(ATVVCapabilities.parse(legacy, allowingLegacyLayout: false))
        #expect(!G9N9NProtocol.acceptsCapabilities(strict))
    }

    @Test func candidateNamesAndStartPacketsAreNarrow() {
        #expect(G9N9NProtocol.isCandidateName(" Chromecast_Remote "))
        #expect(G9N9NProtocol.isCandidateName("小米遥控器"))
        #expect(!G9N9NProtocol.isCandidateName("Bluetooth Keyboard"))
        #expect(!G9N9NProtocol.isCandidateName(nil))
        #expect(G9N9NProtocol.acceptsStreamStart(Data([4, 0, 2, 1])))
        #expect(!G9N9NProtocol.acceptsStreamStart(Data([4, 0, 1, 1])))
        #expect(!G9N9NProtocol.acceptsStreamStart(Data([4, 0, 2])))
        #expect(!G9N9NProtocol.acceptsStreamStart(Data([0, 0, 2, 1])))
    }

    @Test func voiceOnlyOnboardingStillRequiresRealVoiceAndText() {
        var caps = OnboardingCapabilities()
        caps.remoteConnected = true
        #expect(!OnboardingFlowPolicy.canContinue(from: .remote, voiceTool: .other, capabilities: caps))
        caps.controlButtonsSupported = false
        #expect(OnboardingFlowPolicy.canContinue(from: .remote, voiceTool: .other, capabilities: caps))
        #expect(!OnboardingFlowPolicy.canContinue(from: .voiceTest, voiceTool: .other, capabilities: caps))
        caps.voiceSessionStarted = true
        caps.voiceSamplesReceived = true
        caps.voiceSessionEnded = true
        caps.transcriptionAppeared = true
        #expect(OnboardingFlowPolicy.canContinue(from: .voiceTest, voiceTool: .other, capabilities: caps))
        caps.manualTranscriptInputObserved = true
        #expect(!OnboardingFlowPolicy.canContinue(from: .voiceTest, voiceTool: .other, capabilities: caps))
    }
}
