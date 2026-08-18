import SwiftUI

struct ContentView: View {
    @Environment(DrumAppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
            Text("Spatial Object Drums").font(.largeTitle.bold())
            Text("등록한 실물 물체를 찾아 손가락으로 윗면을 두드려 보세요.")
                .multilineTextAlignment(.center)
            Label("Apple Vision Pro 실기기와 정리된 주변 공간이 필요합니다.", systemImage: "visionpro")
                .foregroundStyle(.secondary)

            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            Button(model.isImmersiveSpaceOpen ? "Stop Drumming" : "Start Drumming") {
                Task {
                    if model.isImmersiveSpaceOpen {
                        await dismissImmersiveSpace()
                        model.isImmersiveSpaceOpen = false
                    } else if await openImmersiveSpace(id: DrumAppModel.immersiveSpaceID) == .opened {
                        model.isImmersiveSpaceOpen = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 620, height: 460)
    }
}
