import os
import UIKit
import Foundation
import Synchronization
import AVFAudio
import PushToTalk

extension AVAudioSession.RouteChangeReason: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch(self) {
        case .unknown:
            return "unknown"
        case .newDeviceAvailable:
            return "newDeviceAvailable"
        case .oldDeviceUnavailable:
            return "oldDeviceUnavailable"
        case .categoryChange:
            return "categoryChange"
        case .override:
            return "override"
        case .wakeFromSleep:
            return "wakeFromSleep"
        case .noSuitableRouteForCategory:
            return "noSuitableRouteForCategory"
        case .routeConfigurationChange:
            return "routeConfigurationChange"
        @unknown default:
            return "unknown"
        }
    }
}

class PTT: NSObject, PTChannelRestorationDelegate, PTChannelManagerDelegate {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PTT")
    private let log = PTT.log

    private let channelUUID = UUID()
    private let channelDescriptor = PTChannelDescriptor(name: "Dummy Channel", image: nil)

    private let audioSession = AVAudioSession.sharedInstance()

    private var channelManager: PTChannelManager? = nil
    private var didJoinChannel: Bool = false
    private var didBeginTransmitting: Bool = false
    private var didActivate: Bool = false

    func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
        self.log.info("restoredChannelUUID")
        return self.channelDescriptor
    }

    func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
        self.log.info( "receivedEphemeralPushToken")
    }

    func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult {
        return .leaveChannel
    }

    func channelManager(_ channelManager: PTChannelManager, failedToJoinChannel channelUUID: UUID, error: any Error) {
        self.log.error("failedToJoinChannel: \(error)")
    }
    func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {
        self.log.info("didJoinChannel")

        Task { @MainActor in
            self.didJoinChannel = true

            do {
                try await channelManager.setTransmissionMode(.fullDuplex, channelUUID: self.channelUUID)
                self.log.info("Switched to .fullDuplex mode")
            } catch {
                self.log.error("Falied to set transmission mode: \(error)")
            }

            do {
                try await channelManager.setServiceStatus(.connecting, channelUUID: self.channelUUID)
                self.log.info("Switched to .connecting")

                try await channelManager.setServiceStatus(.ready, channelUUID: self.channelUUID)
                self.log.info("Switched to .ready")
            } catch {
                self.log.error("Falied to set service status: \(error)")
            }
        }
    }

    func channelManager(_ channelManager: PTChannelManager, failedToLeaveChannel channelUUID: UUID, error: any Error) {
        self.log.error("failedToLeaveChannel: \(error)")

        channelManager.setServiceStatus(.unavailable, channelUUID: self.channelUUID)
    }
    func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        self.log.info( "didLeaveChannel")

        Task { @MainActor in
            self.didJoinChannel = false
        }
    }

    func channelManager(_ channelManager: PTChannelManager, failedToBeginTransmittingInChannel channelUUID: UUID, error: any Error) {
        self.log.error("failedToBeginTransmittingInChannel: \(error)")
    }
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        self.log.info("didBeginTransmitting")

        do {
            self.log.info("Configuring audio session category...")
            if(self._useVoiceChatMode.load(ordering: .relaxed)) {
                try self.audioSession.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetooth])
            } else {
                try self.audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.allowBluetooth])
            }

            self.log.info("Forcing audio output to speaker...")
            try self.audioSession.overrideOutputAudioPort(.speaker)

        } catch {
            self.log.error("Failed to configure audio session: \(error)")
        }

        Task { @MainActor in
            self.didBeginTransmitting = true
        }
    }

    func channelManager(_ channelManager: PTChannelManager, failedToStopTransmittingInChannel channelUUID: UUID, error: any Error) {
        self.log.error("failedToStopTransmittingInChannel: \(error)")
    }
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        self.log.info("didEndTransmitting")

        Task { @MainActor in
            if(self.didBeginTransmitting) {
                self.didBeginTransmitting = false
                self.stopRecording()
            }
        }
    }

    func channelManager(_ channelManager: PTChannelManager, didActivate audioSession: AVAudioSession) {
        self.log.info("\("didActivate. category: \(audioSession.category.rawValue), mode: \(audioSession.mode.rawValue)")")

        Task { @MainActor in
            self.didActivate = true

            if(self.didBeginTransmitting) {
                await self.startRecording()
            }
        }
    }

    func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {
        self.log.info("didDeactivate")

        Task { @MainActor in
            if(self.didActivate) {
                self.didActivate = false
                self.stopRecording()
            }
        }
    }

    private class RecorderDelegate: NSObject, AVAudioRecorderDelegate {
        func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
            PTT.log.info("didFinishRecording. successfully: \(flag)")
        }

        func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
            PTT.log.info("encodeErrorDidOccur. error: \(error)")
        }
    }

    @MainActor
    private let recorderDelegate = RecorderDelegate()
    @MainActor
    private var recorder: AVAudioRecorder? = nil
    @MainActor
    private func startRecording() async {
        self.log.info("startRecording")

        do {
            switch(self.implementation) {
            case .AVAudioEngine:
                let engine = AVAudioEngine()
                defer { engine.stop() }
                let inputNode = engine.inputNode // just to create node accessing mic
                try inputNode.setVoiceProcessingEnabled(false)
                try engine.start()
                try await Task.sleep(for: .milliseconds(300))
            case .AVAudioRecorder:
                assert(self.recorder == nil)
                if let recorder = self.recorder {
                    recorder.stop()
                    self.recorder = nil
                }

                let fileManager = FileManager.default
                var path = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                path.appendPathComponent("\(UUID()).aac")

                let settings: [String : Any] = [
                    AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue,
                    AVFormatIDKey : kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 1,
                    AVSampleRateKey: 16000.0
                ]

                let recorder = try AVAudioRecorder(url: path, settings: settings)
                recorder.delegate = self.recorderDelegate
                self.recorder = recorder
                recorder.record()
            }
        } catch {
            self.log.error("PTT Error: \(error)")
        }
    }
    @MainActor
    private func stopRecording() {
        self.log.info("stopRecording")

        guard let recorder = self.recorder else { return }

        self.recorder = nil
        recorder.stop()
    }

    override init() {
        super.init()

        PTChannelManager.channelManager(delegate: self, restorationDelegate: self) { channelManager, error in
            Task {
                if let error = error {
                    self.log.error("Channel Manager access Error: \(error)")
                }

                guard let channelManager = channelManager else { return }

                self.channelManager = channelManager

                channelManager.requestJoinChannel(channelUUID: self.channelUUID, descriptor: self.channelDescriptor)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: self.audioSession,
            queue: OperationQueue.main
        ) { notification in
            let reason: AVAudioSession.RouteChangeReason
            if
                let userInfo = notification.userInfo,
                let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt
            {
                reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) ?? .unknown
            } else {
                reason = .unknown
            }

            if(reason == .categoryChange) {
                let audioSession = AVAudioSession.sharedInstance()
                Self.log.debug("\("routeChangeNotification. reason: \(reason), category: \(audioSession.category.rawValue), mode: \(audioSession.mode.rawValue)")")
            } else {
                Self.log.debug("\("routeChangeNotification. reason: \(reason)")")
            }
        }
    }

    private let _useVoiceChatMode = Atomic<Bool>(true)
    var useVoiceChatMode: Bool {
        get {
            self._useVoiceChatMode.load(ordering: .relaxed)
        }
        set {
            self._useVoiceChatMode.store(newValue, ordering: .relaxed)
        }
    }

    enum ImplementationType {
        case AVAudioEngine
        case AVAudioRecorder
    }
    var implementation: ImplementationType = .AVAudioEngine

    func startPTT() {
        guard let channelManager = self.channelManager else { return }

        self.log.info("startPTT")

        channelManager.requestBeginTransmitting(channelUUID: self.channelUUID)
    }

    func stopPTT() {
        guard let channelManager = self.channelManager else { return }

        self.log.info("stopPTT")

        channelManager.stopTransmitting(channelUUID: self.channelUUID)
    }
}
