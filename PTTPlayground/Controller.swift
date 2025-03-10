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

    var useAVAudioRecorder: Bool {
        get {
            self.ptt.useAudioRecorder
        }
        set {
            self.ptt.useAudioRecorder = newValue
        }
    }

    init() {
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
