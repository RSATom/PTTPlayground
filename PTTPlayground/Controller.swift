import Foundation
import AVFAudio
import SwiftUICore

class Controller: ObservableObject {
    private let ptt = PTT()

    @Published private(set) var pttEnabled: Bool = false

    var breakPtt: Bool {
        get {
            self.ptt.brokeBy != .None
        }
        set {
            self.ptt.brokeBy = newValue ? .VoiceChatMode : .None
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
