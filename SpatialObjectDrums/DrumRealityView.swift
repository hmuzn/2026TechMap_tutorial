import RealityKit
import SwiftUI

struct DrumRealityView: View {
    @Environment(DrumAppModel.self) private var model

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "TrackedDrumsRoot"
            content.add(root)
            Task { await model.start(in: root) }
        }
        .overlay(alignment: .top) {
            Text(model.status)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .glassBackgroundEffect()
                .padding(24)
        }
        .onDisappear { model.stop() }
    }
}

