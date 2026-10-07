import RealityKit
import SwiftUI

struct DrumRealityView: View {
    @Environment(DrumAppModel.self) private var model
    @State private var root = Entity()

    var body: some View {
        RealityView { content in
            root.name = "TrackedDrumsRoot"
            content.add(root)
        }
        .task { await model.start(in: root) }
        .overlay(alignment: .top) {
            VStack(spacing: 10) {
                Label(
                    model.status,
                    systemImage: model.trackedObjectCount > 0
                        ? "checkmark.circle.fill"
                        : "viewfinder.circle"
                )
                .font(.title3.bold())
                .foregroundStyle(model.trackedObjectCount > 0 ? Color.green : Color.primary)

                if model.trackedObjectCount > 0 {
                    Text(
                        model.trackedHandCount > 0
                            ? "손 추적 준비 완료 · 타격면을 위에서 아래로 통과하세요."
                            : "키보드 인식 완료 · 손을 시야 안에 보여주세요."
                    )
                    .font(.callout)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassBackgroundEffect()
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(model.trackedObjectCount > 0 ? Color.green.opacity(0.18) : Color.clear)
            }
            .padding(24)
        }
        .onDisappear { model.stop() }
    }
}
