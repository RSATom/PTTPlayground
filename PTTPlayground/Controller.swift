import Foundation
import AVFAudio
import SwiftUICore

class Controller: ObservableObject {
    private let ptt = PTT()

    @Published private(set) var pttEnabled: Bool = false

    var useVoiceChatMode: Bool {
        get {
            self.ptt.useVoiceChatMode
        }
        set {
            self.ptt.useVoiceChatMode = newValue
        }
    }

    @Published private(set) var useImplementation: PTT.ImplementationType = .AVAudioEngine {
        didSet {
            self.ptt.implementation = self.useImplementation
        }
    }
    var useAVAudioEngine: Bool {
        get {
            self.useImplementation == .AVAudioEngine
        }
        set {
            self.useImplementation = .AVAudioEngine
        }
    }
    var useAVAudioRecorder: Bool {
        get {
            self.useImplementation == .AVAudioRecorder
        }
        set {
            self.useImplementation = .AVAudioRecorder
        }
    }

    init() {
        self.ptt.implementation = self.useImplementation
        AVAudioApplication.requestRecordPermission() { granted in
            Task { @MainActor in
                self.pttEnabled = granted
            }
        }
    }

    func pttButtonPressed() {
        self.ptt.startPTT()
    }

    func pttButtonReleased() {
        self.ptt.stopPTT()
    }
}
