import ARKit
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class TrackedDrum {

    private static let strikePlaneOffset: Float = 0.012
    private static let restingOpacity: Float = 0.42
    private static let hitOpacity: Float = 0.9
    private static let minimumHitIntensity: Float = 0.15

    let id: UUID
    let displayName: String
    let entity = Entity()



    private let hitPlaneY: Float
    private let audio: AudioFileResource
    private(set) var isTracked = true

    init(anchor: ObjectAnchor) async throws {
        id = anchor.id
        boundsMin = anchor.boundingBox.min
        boundsMax = anchor.boundingBox.max
        hitPlaneY = anchor.boundingBox.max.y + Self.strikePlaneOffset
        let selectedProfile = DrumProfile.forReferenceObject(named: anchor.referenceObject.name)
        displayName = selectedProfile.displayName








        feedback.components.set(OpacityComponent(opacity: Self.restingOpacity))


        entity.spatialAudio = SpatialAudioComponent(gain: -6)
        audio = try await AudioFileResource(named: selectedProfile.audioResource)
    }

    func update(anchor: ObjectAnchor) {
        isTracked = anchor.isTracked
        entity.isEnabled = anchor.isTracked
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
    }

    func hitIntensity(from previousWorld: SIMD3<Float>, to currentWorld: SIMD3<Float>) -> Float? {
        let inverse = entity.transformMatrix(relativeTo: nil).inverse
        let previous = (inverse * SIMD4<Float>(previousWorld, 1)).xyz
        let current = (inverse * SIMD4<Float>(currentWorld, 1)).xyz
        let top = hitPlaneY
        let crossedTop = previous.y > top && current.y <= top
        let verticalDistance = previous.y - current.y
        guard crossedTop, verticalDistance > .ulpOfOne else { return nil }
        let crossingFraction = (previous.y - top) / verticalDistance
        let crossing = previous + (current - previous) * crossingFraction
        let insideXZ = crossing.x >= boundsMin.x && crossing.x <= boundsMax.x &&
            crossing.z >= boundsMin.z && crossing.z <= boundsMax.z
        guard insideXZ else { return nil }
        return min(max(verticalDistance / 0.04, Self.minimumHitIntensity), 1)
    }

    func play(intensity: Float) {
        let normalizedIntensity = min(
            max((intensity - Self.minimumHitIntensity) / (1 - Self.minimumHitIntensity), 0),
            1
        )
        entity.spatialAudio?.gain = -18 + 18 * Double(normalizedIntensity)
        entity.playAudio(audio)
        feedback.components.set(OpacityComponent(opacity: Self.hitOpacity))
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            feedback.components.set(OpacityComponent(opacity: Self.restingOpacity))
        }
    }
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { [x, y, z] }
}
