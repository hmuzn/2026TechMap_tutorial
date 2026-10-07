import ARKit
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class TrackedDrum {
    private static let feedbackHeight: Float = 0.004
    private static let restingOpacity: Float = 0.42
    private static let hitOpacity: Float = 0.9

    let id: UUID
    let displayName: String
    let entity = Entity()
    private let feedback: ModelEntity
    private let boundsMin: SIMD3<Float>
    private let boundsMax: SIMD3<Float>
    private let hitPlaneY: Float
    private let hitDetector: HitDetector
    private let audio: AudioFileResource
    private var feedbackTask: Task<Void, Never>?
    private(set) var isTracked = true

    init(anchor: ObjectAnchor, tuning: DrumTuning) async throws {
        id = anchor.id
        boundsMin = anchor.boundingBox.min
        boundsMax = anchor.boundingBox.max
        hitPlaneY = anchor.boundingBox.max.y + tuning.strikePlaneOffset
        hitDetector = HitDetector(
            boundsMin: anchor.boundingBox.min,
            boundsMax: anchor.boundingBox.max,
            hitPlaneY: hitPlaneY
        )
        let selectedProfile = DrumProfile.forReferenceObject(named: anchor.referenceObject.name)
        displayName = selectedProfile.displayName

        let size = boundsMax - boundsMin
        let center = (boundsMin + boundsMax) / 2
        feedback = ModelEntity(
            mesh: .generateBox(size: [size.x, Self.feedbackHeight, size.z]),
            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
        )
        feedback.position = [center.x, hitPlaneY, center.z]
        feedback.components.set(OpacityComponent(opacity: Self.restingOpacity))
        feedback.isEnabled = tuning.showsStrikeSurface
        entity.addChild(feedback)
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        entity.spatialAudio = SpatialAudioComponent(gain: -6)
        audio = try await AudioFileResource(named: selectedProfile.audioResource)
    }







    func apply(tuning: DrumTuning) {
        feedback.isEnabled = tuning.showsStrikeSurface
    }

    func hitIntensity(
        from previousWorld: SIMD3<Float>,
        to currentWorld: SIMD3<Float>,
        elapsed: Duration,
        tuning: DrumTuning
    ) -> Float? {
        let inverse = entity.transformMatrix(relativeTo: nil).inverse
        let previous = (inverse * SIMD4<Float>(previousWorld, 1)).xyz
        let current = (inverse * SIMD4<Float>(currentWorld, 1)).xyz
        let components = elapsed.components
        let elapsedSeconds =
            Float(components.seconds)
            + Float(components.attoseconds) / 1_000_000_000_000_000_000
        return hitDetector.intensity(
            from: previous,
            to: current,
            elapsedSeconds: elapsedSeconds,
            tuning: tuning
        )
    }

    func play(intensity: Float) {
        let normalizedIntensity = min(max(intensity, 0), 1)
        entity.spatialAudio?.gain = -18 + 18 * Double(normalizedIntensity)
        entity.playAudio(audio)
        feedback.components.set(OpacityComponent(opacity: Self.hitOpacity))
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            self?.feedback.components.set(OpacityComponent(opacity: Self.restingOpacity))
        }
    }
}

extension SIMD4 where Scalar == Float {
    fileprivate var xyz: SIMD3<Float> { [x, y, z] }
}
