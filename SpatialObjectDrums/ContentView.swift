import SwiftUI

struct ContentView: View {
    @Environment(DrumAppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isTransitioning = false
    @State private var transitionID = UUID()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
            Text("Spatial Object Drums").font(.largeTitle.bold())
            Text("iPhone 17 또는 Apple Magic Keyboard를 평평한 테이블에 놓으세요.")
                .multilineTextAlignment(.center)
            Label("인식된 물체 위의 초록색 영역을 손가락으로 가볍게 내려치세요.", systemImage: "hand.tap")
                .foregroundStyle(.secondary)
            Label("Apple Vision Pro 실기기와 정리된 주변 공간이 필요합니다.", systemImage: "visionpro")
                .foregroundStyle(.secondary)
            Label("인식되면 물체 위와 몰입 화면 상단에 초록색 표시가 나타납니다.", systemImage: "viewfinder")
                .foregroundStyle(.secondary)

            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            Button(buttonTitle) {
                Task { @MainActor in
                    guard !isTransitioning else { return }
                    isTransitioning = true

                    if model.isImmersiveSpaceOpen {
                        await dismissImmersiveSpace()
                        model.stop()
                        isTransitioning = false
                    } else {
                        model.errorMessage = nil
                        guard await model.prepareForImmersiveSpace() else {
                            isTransitioning = false
                            return
                        }

                        let requestID = UUID()
                        transitionID = requestID
                        let timeoutTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(12))
                            guard !Task.isCancelled,
                                  transitionID == requestID,
                                  isTransitioning else { return }

                            transitionID = UUID()
                            isTransitioning = false
                            model.errorMessage = "Immersive Space 전환이 응답하지 않습니다. 다른 몰입형 앱을 종료하고 Vision Pro를 다시 잠금 해제한 뒤 재시도하세요."
                            await dismissImmersiveSpace()
                        }

                        let result = await openImmersiveSpace(id: DrumAppModel.immersiveSpaceID)
                        timeoutTask.cancel()
                        guard transitionID == requestID else { return }

                        transitionID = UUID()
                        isTransitioning = false
                        switch result {
                        case .opened:
                            model.isImmersiveSpaceOpen = true
                        case .userCancelled:
                            model.errorMessage = "Immersive Space 열기가 취소되었습니다."
                        case .error:
                            model.errorMessage = "Immersive Space를 열 수 없습니다. Vision Pro 연결 상태를 확인하세요."
                        @unknown default:
                            model.errorMessage = "알 수 없는 이유로 Immersive Space를 열 수 없습니다."
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isTransitioning)
        }
        .padding(40)
        .frame(width: 620, height: 460)
    }

    private var buttonTitle: String {
        if isTransitioning {
            return model.isImmersiveSpaceOpen ? "종료하는 중…" : "준비하는 중…"
        }
        return model.isImmersiveSpaceOpen ? "Stop Drumming" : "Start Drumming"
    }
}
