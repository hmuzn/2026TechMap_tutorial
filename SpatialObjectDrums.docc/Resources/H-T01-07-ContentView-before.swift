import Foundation
import SwiftUI

struct ContentView: View {






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
























































            .padding(40)
        }
        .frame(width: 640, height: 700)
    }






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
