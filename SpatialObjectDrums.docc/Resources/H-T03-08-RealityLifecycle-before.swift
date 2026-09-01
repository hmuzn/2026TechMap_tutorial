import RealityKit
import SwiftUI

struct DrumRealityView: View {
    @Environment(DrumAppModel.self) private var model


    var body: some View {





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
                    Text("Magic Keyboard 위의 초록색 가상 타격면을 손가락으로 통과하세요.")
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

    }
}
