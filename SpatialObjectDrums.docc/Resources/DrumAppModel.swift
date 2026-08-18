import ARKit
import Observation
import RealityKit

@MainActor
@Observable
final class DrumAppModel {
    static let immersiveSpaceID = "DrumSpace"

    var isImmersiveSpaceOpen = false
    var status = "참조 물체를 찾는 중…"
    var errorMessage: String?

    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private var objectTracking: ObjectTrackingProvider?
    private(set) var trackedDrums: [UUID: TrackedDrum] = [:]
    private var previousTips: [HandAnchor.Chirality: SIMD3<Float>] = [:]
    private var lastHitAt: [UUID: ContinuousClock.Instant] = [:]

    func start(in root: Entity) async {
        do {
            guard HandTrackingProvider.isSupported,
                  ObjectTrackingProvider.isSupported else {
                throw DrumError.unsupportedDevice
            }

            let references = try await loadReferenceObjects()
            guard !references.isEmpty else {
                throw DrumError.missingReferenceObjects
            }

            let objectProvider = ObjectTrackingProvider(referenceObjects: references)
            objectTracking = objectProvider
            try await session.run([objectProvider, handTracking])

            async let objects: Void = consumeObjectUpdates(from: objectProvider, root: root)
            async let hands: Void = consumeHandUpdates()
            _ = await (objects, hands)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        session.stop()
        trackedDrums.values.forEach { $0.entity.removeFromParent() }
        trackedDrums.removeAll()
        previousTips.removeAll()
        lastHitAt.removeAll()
    }

    private func loadReferenceObjects() async throws -> [ReferenceObject] {
        let urls = Bundle.main.urls(
            forResourcesWithExtension: "referenceobject",
            subdirectory: "ReferenceObjects"
        ) ?? []

        return try await withThrowingTaskGroup(of: ReferenceObject.self) { group in
            for url in urls {
                group.addTask { try await ReferenceObject(from: url) }
            }
            return try await group.reduce(into: []) { result, reference in
                result.append(reference)
            }
        }
    }

    private func consumeObjectUpdates(
        from provider: ObjectTrackingProvider,
        root: Entity
    ) async {
        for await update in provider.anchorUpdates {
            let anchor = update.anchor

            switch update.event {
            case .added:
                let drum = await TrackedDrum(anchor: anchor)
                trackedDrums[anchor.id] = drum
                root.addChild(drum.entity)
            case .updated:
                trackedDrums[anchor.id]?.update(anchor: anchor)
            case .removed:
                trackedDrums.removeValue(forKey: anchor.id)?.entity.removeFromParent()
            }

            status = trackedDrums.isEmpty
                ? "참조 물체를 찾는 중…"
                : "\(trackedDrums.count)개 물체 준비 완료"
        }
    }

    private func consumeHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let hand = update.anchor
            guard hand.isTracked,
                  let skeleton = hand.handSkeleton else { continue }

            let tip = skeleton.joint(.indexFingerTip)
            guard tip.isTracked else { continue }

            let transform = hand.originFromAnchorTransform * tip.anchorFromJointTransform
            let current = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            defer { previousTips[hand.chirality] = current }
            guard let previous = previousTips[hand.chirality] else { continue }

            for drum in trackedDrums.values where drum.isTracked {
                guard let intensity = drum.hitIntensity(from: previous, to: current) else {
                    continue
                }

                let now = ContinuousClock.now
                if let last = lastHitAt[drum.id], now - last < .milliseconds(100) {
                    continue
                }

                lastHitAt[drum.id] = now
                drum.play(intensity: intensity)
            }
        }
    }
}

enum DrumError: LocalizedError {
    case unsupportedDevice
    case missingReferenceObjects

    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            "이 기기는 Object Tracking 또는 Hand Tracking을 지원하지 않습니다."
        case .missingReferenceObjects:
            "ReferenceObjects 폴더에 .referenceobject 파일을 추가하세요."
        }
    }
}
