// SPDX-License-Identifier: GPL-3.0-only
import Foundation

/// Reuses SayAll's BLE transport, ADPCM decoder and delegate boundary. This
/// voice-only adapter does not seize HID devices or implement button mapping.
final class PublicChromecastTransport: XiaomiBluetoothBridgeDelegate {
    private let settings: AppSettings
    private lazy var bridge = XiaomiBluetoothBridge(settings: settings, delegate: self, chromecastOnly: true)
    private var running = false
    private var voiceActive = false
    var onStatus: ((ChromecastLinkStatus) -> Void)?
    var onStart: (() -> Void)?
    var onStop: ((ChromecastVoiceEndReason) -> Void)?
    var onSamples: (([Int16], Int) -> Void)?

    init(settings: AppSettings) { self.settings = settings }
    func start() {
        guard !running else { return }
        running = true
        bridge.start()
    }
    func stop() {
        guard running else { return }
        running = false
        bridge.stop()
    }
    func reconnect() { bridge.reconnectNow() }
    func endVoice() { _ = bridge.requestMicrophoneClose() }

    func bluetoothBridge(_ bridge: XiaomiBluetoothBridge, didChange state: BluetoothBridgeState) {
        switch state {
        case .ready: onStatus?(.connected(displayName: "Google Chromecast Remote"))
        case .scanning: onStatus?(.searching)
        case .connecting, .discovering: onStatus?(.connecting)
        case .bluetoothUnavailable: onStatus?(.unauthorized)
        case .stopped, .reconnecting, .failed:
            if voiceActive {
                voiceActive = false
                onStop?(.cancelled("link_unavailable"))
            }
            onStatus?(.disconnected)
        }
    }
    func bluetoothBridgeDidStartVoice(_ bridge: XiaomiBluetoothBridge) {
        guard running, !voiceActive else { return }
        voiceActive = true
        onStart?()
    }
    func bluetoothBridgeDidStopVoice(_ bridge: XiaomiBluetoothBridge) {
        guard voiceActive else { return }
        voiceActive = false
        onStop?(running ? .holdRelease : .hostStop)
    }
    func bluetoothBridge(_ bridge: XiaomiBluetoothBridge, didDecode samples: [Int16]) {
        guard running, voiceActive else { return }
        onSamples?(samples, 0)
    }
    func bluetoothBridge(_ bridge: XiaomiBluetoothBridge, didUpdateBatteryLevel level: Int?) {}
    func bluetoothBridge(_ bridge: XiaomiBluetoothBridge, didIdentifyRemoteModel model: XiaomiRemoteModel) {}
    func bluetoothBridge(_ bridge: XiaomiBluetoothBridge, didUpdatePowerState state: RemotePowerState?) {}
    func bluetoothBridgeDeviceNameDidChange(_ bridge: XiaomiBluetoothBridge) {}
}
