import SwiftUI

struct ContentView: View {
    @StateObject private var controller = Controller()
    @State private var recordButtonPressed = false
    @GestureState private var recordButtonPressedState = false

    var body: some View {
        VStack {
            Spacer().frame(maxHeight: UIScreen.main.bounds.size.height * 0.05)

            Divider()
            Spacer().frame(maxHeight: UIScreen.main.bounds.size.height * 0.03)
            HStack {
                Spacer()
                Toggle(isOn: $controller.useAVAudioEngine) {
                    Text("Use AVAudioEngine")
                }
                Spacer()
            }
            Spacer().frame(maxHeight: UIScreen.main.bounds.size.height * 0.03)
            HStack {
                Spacer()
                Toggle(isOn: $controller.useAVAudioRecorder) {
                    Text("Use AVAudioRecorder")
                }
                Spacer()
            }
            Spacer().frame(maxHeight: UIScreen.main.bounds.size.height * 0.03)
            Divider()
            Spacer().frame(maxHeight: UIScreen.main.bounds.size.height * 0.03)
            HStack {
                Spacer()
                Toggle(isOn: $controller.useVoiceChatMode) {
                    Text("Use .voiceChat mode")
                }
                Spacer()
            }
            Spacer().frame(maxHeight: UIScreen.main.bounds.size.height * 0.03)
            Divider()

            Spacer()

            Button() {} label: {
                Image(systemName: self.recordButtonPressedState ? "mic.fill" : "mic").imageScale(.large)
            }
            .disabled(!controller.pttEnabled)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                .updating($recordButtonPressedState) { _, recordButtonPressedState, _ in
                    recordButtonPressedState = true
                }
                .onChanged { _ in
                    if(!recordButtonPressed) {
                        controller.pttButtonPressed()
                        recordButtonPressed = true
                    }
                }
                .onEnded { _ in
                    recordButtonPressed = false
                    controller.pttButtonReleased()
                }
            )

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
