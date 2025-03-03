import SwiftUI

struct ContentView: View {
    @StateObject private var controller = Controller()
    @State private var recordButtonPressed = false
    @GestureState private var recordButtonPressedState = false

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()
                Toggle(isOn: $controller.breakPtt) {
                    Text("Break PTT Start sound")
                }
                Spacer()
            }

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
