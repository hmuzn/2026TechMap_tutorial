import ARKit
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class TrackedDrum {
    let id: UUID
    let entity = Entity()

    private let feedback: ModelEntity
    private let profile: DrumProfile
    private let bounds: ObjectAnchor.AxisAlignedBoundingBox
    private var audio: AudioFileResource?
    private(set) var isTracked = true

    init(anchor: ObjectAnchor) async {
        id = anchor.id
        bounds = anchor.boundingBox
        profile = DrumProfile.forReferenceObject(named: anchor.referenceObject.name)

        let size = anchor.boundingBox.extent
        feedback = ModelEntity(
            mesh: .generateBox(size: [size.x, 0.004, size.z]),
            materials: [
                SimpleMaterial(
                    color: .orange.withAlphaComponent(0.28),
                    isMetallic: false
                )
            ]
        )
        feedback.position.y = anchor.boundingBox.max.y + 0.004
        entity.addChild(feedback)

        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        entity.spatialAudio = SpatialAudioComponent(gain: -6)
        audio = try? await AudioFileResource(named: profile.audioResource)
    }

    func update(anchor: ObjectAnchor) {
        isTracked = anchor.isTracked
        entity.isEnabled = anchor.isTracked
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
    }

    func hitIntensity(
        from previousWorld: SIMD3<Float>,
        to currentWorld: SIMD3<Float>
    ) -> Float? {
        let inverse = entity.transformMatrix(relativeTo: nil).inverse
        let previous = (inverse * SIMD4<Float>(previousWorld, 1)).xyz
        let current = (inverse * SIMD4<Float>(currentWorld, 1)).xyz
        let top = bounds.max.y

        let crossedTop = previous.y > top && current.y <= top
        let insideXZ = current.x >= bounds.min.x && current.x <= bounds.max.x
            && current.z >= bounds.min.z && current.z <= bounds.max.z

        guard crossedTop, insideXZ else { return nil }
        return min(max((previous.y - current.y) / 0.04, 0.15), 1)
    }

    func play(intensity: Float) {
        guard let audio else { return }

        entity.spatialAudio?.gain = Double(-18 + 18 * intensity)
        entity.playAudio(audio)
        feedback.components.set(OpacityComponent(opacity: 0.9))

        Task {
            try? await Task.sleep(for: .milliseconds(90))
            feedback.components.set(OpacityComponent(opacity: 0.28))
        }
    }
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { [x, y, z] }
}
