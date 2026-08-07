import SwiftUI

@main
struct SpatialObjectDrumsApp: App {
    @State private var model = DrumAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .windowStyle(.plain)

        ImmersiveSpace(id: DrumAppModel.immersiveSpaceID) {
            DrumRealityView()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

