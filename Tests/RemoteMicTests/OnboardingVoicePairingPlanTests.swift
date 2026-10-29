import Foundation
import Testing
@testable import RemoteMic

@Suite("Onboarding 输入工具与控制来源配对")
struct OnboardingVoicePairingPlanTests {
    @Test func selectedRemotePhotoFollowsTheControlSource() {
        #expect(
            OnboardingRemotePhotoKind.resolve(
                source: .xiaomiRemote,
                selectedModel: nil
            ) == .bundled(resourceName: "RC003-remote-photo")
        )
        #expect(
            OnboardingRemotePhotoKind.resolve(
                source: .siriRemote,
                selectedModel: nil
            ) == .siriRemote
        )
        #expect(
            OnboardingRemotePhotoKind.resolve(
                source: .chromecastRemote,
                selectedModel: nil
            ) == .chromecastRemote
        )
        #expect(
            OnboardingRemotePhotoKind.resolve(
                source: .xiaomiRemote,
                selectedModel: .unknown
            ) == .bundled(resourceName: "RC003-remote-photo")
        )
    }

    @Test func verifiedBindingWinsDuringOnboardingRerun() throws {
        let suiteName = "RemoteMicTests.Onboarding.VerifiedBindingPriority.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        #if SAYALL_PUBLIC_CHROMECAST_ENABLED
        let shortcut = VoiceKeyMode.function
        let gesture = VoiceGestureMode.hold
        #else
        let shortcut = VoiceKeyMode.rightCommand
        let gesture = VoiceGestureMode.toggle
        #endif
        let learned = VoiceToolUserBinding(
            tool: .doubao,
            shortcut: shortcut,
            gestureMode: gesture,
            source: .userLearned,
            validationState: .verified,
            verifiedToolVersion: nil,
            verifiedAt: Date(timeIntervalSince1970: 1)
        )
        settings.setOnboardingVoiceTool(.doubao)
        settings.setOnboardingControlSource(.chromecastRemote)

        let learnedPlan = try #require(OnboardingVoicePairingPlan.resolve(
            tool: settings.onboardingVoiceTool,
            controlSource: settings.onboardingControlSource,
            userBinding: learned
        ))
        settings.beginOnboardingVoiceTrial(learnedPlan)
        settings.verifyOnboardingVoiceBinding(at: Date(timeIntervalSince1970: 2))

        let plan = try #require(OnboardingVoicePairingPlan.resolve(
            tool: settings.onboardingVoiceTool,
            controlSource: settings.onboardingControlSource,
            userBinding: settings.verifiedVoiceToolBinding
        ))
        #expect(plan.binding.shortcut == shortcut)
        #expect(plan.binding.gestureMode == gesture)
        #expect(plan.binding.source == .userLearned)
    }

    @Test func documentedDefaultsMatchTheCapabilityMatrix() throws {
        let doubao = VoiceToolAdapterProfile.profile(for: .doubao)
        #expect(doubao.defaultShortcutByMode[.hold] == .function)
        #expect(doubao.defaultShortcutByMode[.toggle] == .rightCommand)

        let weixin = VoiceToolAdapterProfile.profile(for: .weixin)
        #expect(weixin.defaultShortcutByMode[.hold] == .function)
        #expect(weixin.defaultShortcutByMode[.toggle] == .rightCommand)

        for tool in [OnboardingVoiceTool.typeless, .vokie] {
            let profile = VoiceToolAdapterProfile.profile(for: tool)
            #expect(profile.defaultShortcutByMode[.toggle] == .function)
        }
        #expect(VoiceToolAdapterProfile.profile(for: .vokie).defaultShortcutByMode[.hold] == nil)
    }

    @Test func holdOnlyRemoteUsesNativeHoldForDoubaoAndFnConversionForToggleOnlyTools() throws {
        let doubao = try #require(OnboardingVoicePairingPlan.resolve(
            tool: .doubao,
            controlSource: .xiaomiRemote
        ))
        #expect(doubao.binding.gestureMode == .hold)
        #expect(doubao.binding.shortcut == .function)
        #expect(!doubao.fnTapModeEnabled)

        for tool in [OnboardingVoiceTool.typeless, .vokie] {
            let plan = try #require(OnboardingVoicePairingPlan.resolve(
                tool: tool,
                controlSource: .xiaomiRemote
            ))
            #expect(plan.binding.gestureMode == .toggle)
            #expect(plan.binding.shortcut == .function)
            #expect(plan.fnTapModeEnabled)
        }
    }

    @Test func chromecastUsesNativeToggleWithoutFnTapConversion() throws {
        let doubao = try #require(OnboardingVoicePairingPlan.resolve(
            tool: .doubao,
            controlSource: .chromecastRemote
        ))
        #if SAYALL_PUBLIC_CHROMECAST_ENABLED
        #expect(doubao.binding.gestureMode == .hold)
        #expect(doubao.binding.shortcut == .function)
        #expect(!doubao.fnTapModeEnabled)
        #expect(doubao.chromecastVoiceMode == .hold)
        #else
        #expect(doubao.binding.gestureMode == .toggle)
        #expect(doubao.binding.shortcut == .rightCommand)
        #expect(!doubao.fnTapModeEnabled)
        #expect(doubao.chromecastVoiceMode == .toggle)
        #endif

        let typeless = try #require(OnboardingVoicePairingPlan.resolve(
            tool: .typeless,
            controlSource: .chromecastRemote
        ))
        #expect(typeless.binding.shortcut == .function)
        #if SAYALL_PUBLIC_CHROMECAST_ENABLED
        #expect(typeless.fnTapModeEnabled)
        #expect(typeless.chromecastVoiceMode == .hold)
        #else
        #expect(!typeless.fnTapModeEnabled)
        #endif
    }

    @Test func appleAndWebExposeHoldAndToggle() {
        #expect(OnboardingControlSource.appleCompanion.supportedGestureModes == [.hold, .toggle])
        #expect(OnboardingControlSource.webRemote.supportedGestureModes == [.hold, .toggle])
    }

    @Test func learnedBindingWinsAndIncompatibleConversionIsRejected() throws {
        let learned = VoiceToolUserBinding(
            tool: .doubao,
            shortcut: .rightCommand,
            gestureMode: .toggle,
            source: .userLearned,
            validationState: .verified,
            verifiedToolVersion: nil,
            verifiedAt: Date(timeIntervalSince1970: 1)
        )
        let chromecast = OnboardingVoicePairingPlan.resolve(
            tool: .doubao,
            controlSource: .chromecastRemote,
            userBinding: learned
        )
        #if SAYALL_PUBLIC_CHROMECAST_ENABLED
        #expect(chromecast == nil)
        #else
        #expect(try #require(chromecast).binding == learned)
        #endif

        #expect(OnboardingVoicePairingPlan.resolve(
            tool: .doubao,
            controlSource: .xiaomiRemote,
            userBinding: learned
        ) == nil)
    }

    @Test func restartDoesNotOverwriteExistingVoiceConfiguration() throws {
        let suiteName = "RemoteMicTests.Onboarding.BindingRestart.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.voiceKeyMode = .rightOption
        settings.voiceFnTapModeEnabled = false
        settings.restartOnboarding()

        #expect(settings.voiceKeyMode == .rightOption)
        #expect(!settings.voiceFnTapModeEnabled)
    }

    @Test func stagedBindingRestoresOnFailureAndCommitsOnlyAfterVerification() throws {
        let suiteName = "RemoteMicTests.Onboarding.BindingTransaction.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.voiceKeyMode = .rightOption
        settings.voiceFnTapModeEnabled = false
        settings.setOnboardingVoiceTool(.typeless)
        settings.setOnboardingControlSource(.xiaomiRemote)
        let plan = try #require(OnboardingVoicePairingPlan.resolve(
            tool: .typeless,
            controlSource: .xiaomiRemote
        ))
        settings.beginOnboardingVoiceTrial(plan)
        #expect(settings.voiceKeyMode == .function)
        #expect(settings.voiceFnTapModeEnabled)
        #expect(settings.verifiedVoiceToolBinding == nil)

        settings.discardOnboardingVoiceTrial()
        #expect(settings.voiceKeyMode == .rightOption)
        #expect(!settings.voiceFnTapModeEnabled)

        settings.beginOnboardingVoiceTrial(plan)
        settings.verifyOnboardingVoiceBinding(at: Date(timeIntervalSince1970: 2))
        #expect(settings.verifiedVoiceToolBinding?.validationState == .verified)
        #expect(settings.voiceKeyMode == .function)
        #expect(settings.voiceFnTapModeEnabled)

        let resumed = AppSettings(defaults: defaults)
        #expect(resumed.verifiedVoiceToolBinding?.tool == .typeless)
        #expect(resumed.voiceKeyMode == .function)
        #expect(resumed.voiceFnTapModeEnabled)
    }

    @Test func publicBuildOnlyOffersXiaomiRemote() {
        #if SAYALL_SIRI_REMOTE_ENABLED || SAYALL_CHROMECAST_ENABLED || SAYALL_MAC_REMOTE_ENABLED
        #expect(OnboardingBuildCapabilities.availableControlSources.contains(.xiaomiRemote))
        #else
        #expect(OnboardingBuildCapabilities.availableControlSources == [.xiaomiRemote])
        #endif
    }
}
