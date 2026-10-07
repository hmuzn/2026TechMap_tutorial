import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(DrumAppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isTransitioning = false
    @State private var transitionID = UUID()

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                Text("Spatial Object Drums").font(.largeTitle.bold())
                Text("Apple 샘플과 대응하는 Magic Keyboard를 평평한 테이블에 놓으세요.")
                    .multilineTextAlignment(.center)
                Label("키보드 위의 초록색 가상 타격면을 손가락으로 통과하세요.", systemImage: "hand.tap")
                    .foregroundStyle(.secondary)
                Label("Apple Vision Pro 실기기와 정리된 주변 공간이 필요합니다.", systemImage: "visionpro")
                    .foregroundStyle(.secondary)

                DisclosureGroup("연주 감도 설정") {
                    VStack(spacing: 16) {
                        settingSlider(
                            title: "타격면 높이",
                            value: $model.strikePlaneOffset,
                            range: 0.005...0.03,
                            valueLabel: String(format: "%.0f mm", model.strikePlaneOffset * 1_000)
                        )
                        settingSlider(
                            title: "최소 타격 속도",
                            value: $model.minimumStrikeSpeed,
                            range: 0.08...0.6,
                            valueLabel: String(format: "%.2f m/s", model.minimumStrikeSpeed)
                        )
                        settingSlider(
                            title: "연타 간격",
                            value: $model.cooldownMilliseconds,
                            range: 50...250,
                            valueLabel: String(format: "%.0f ms", model.cooldownMilliseconds)
                        )
                        Toggle("초록색 타격면 표시", isOn: $model.showsStrikeSurface)
                    }
                    .padding(.top, 14)
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .disabled(model.isImmersiveSpaceOpen || isTransitioning)

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
                                    isTransitioning
                                else { return }

                                transitionID = UUID()
                                isTransitioning = false
                                model.errorMessage =
                                    "Immersive Space 전환이 응답하지 않습니다. 다른 몰입형 앱을 종료하고 Vision Pro를 다시 잠금 해제한 뒤 재시도하세요."
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
        }
        .frame(width: 640, height: 700)
    }

    private var buttonTitle: String {
        if isTransitioning {
            return model.isImmersiveSpaceOpen ? "종료하는 중…" : "준비하는 중…"
        }
        return model.isImmersiveSpaceOpen ? "Stop Drumming" : "Start Drumming"
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueLabel: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueLabel).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
