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
    var trackedObjectCount = 0

    @ObservationIgnored private var session: ARKitSession?
    @ObservationIgnored private var handTracking: HandTrackingProvider?
    @ObservationIgnored private var objectTracking: ObjectTrackingProvider?
    @ObservationIgnored private(set) var trackedDrums: [UUID: TrackedDrum] = [:]
    @ObservationIgnored private var previousTips: [HandAnchor.Chirality: SIMD3<Float>] = [:]
    @ObservationIgnored private var lastHitAt: [UUID: ContinuousClock.Instant] = [:]
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var activeRunID: UUID?
    @ObservationIgnored private var preparedReferenceObjects: [ReferenceObject]?

    func prepareForImmersiveSpace() async -> Bool {
        errorMessage = nil
        status = "추적 모델을 확인하는 중…"

        do {
            guard HandTrackingProvider.isSupported, ObjectTrackingProvider.isSupported else {
                throw DrumError.unsupportedDevice
            }

            let references = try await loadReferenceObjects()
            guard !references.isEmpty else { throw DrumError.missingReferenceObjects }
            try Task.checkCancellation()

            preparedReferenceObjects = references
            status = "Immersive Space를 여는 중…"
            return true
        } catch is CancellationError {
            status = "준비가 취소되었습니다."
            return false
        } catch {
            preparedReferenceObjects = nil
            status = "추적을 시작할 수 없습니다."
            errorMessage = error.localizedDescription
            return false
        }
    }

    func start(in root: Entity) async {
        guard !isRunning else { return }
        let runID = UUID()
        activeRunID = runID
        isRunning = true
        errorMessage = nil
        status = "추적 기능을 준비하는 중…"

        defer {
            if activeRunID == runID {
                activeRunID = nil
                isRunning = false
            }
        }

        do {
            guard HandTrackingProvider.isSupported, ObjectTrackingProvider.isSupported else {
                throw DrumError.unsupportedDevice
            }
            let references: [ReferenceObject]
            if let preparedReferenceObjects {
                references = preparedReferenceObjects
            } else {
                references = try await loadReferenceObjects()
            }
            guard !references.isEmpty else { throw DrumError.missingReferenceObjects }
            preparedReferenceObjects = references
            try Task.checkCancellation()
            guard activeRunID == runID else { return }

            // Creating ARKitSession starts a connection to visionOS system
            // services. Defer it until a usable reference object exists so the
            // app's window can still launch while training assets are pending.
            let session = ARKitSession()
            let handTracking = HandTrackingProvider()
            let objectProvider = ObjectTrackingProvider(referenceObjects: references)
            self.session = session
            self.handTracking = handTracking
            objectTracking = objectProvider
            try await session.run([objectProvider, handTracking])
            status = "참조 물체를 찾는 중…"

            async let objects: Void = consumeObjectUpdates(from: objectProvider, root: root, runID: runID)
            async let hands: Void = consumeHandUpdates(from: handTracking, runID: runID)
            _ = await (objects, hands)
            if activeRunID == runID {
                resetTrackingSession()
            }
        } catch is CancellationError {
            guard activeRunID == runID else { return }
            resetTrackingSession()
            status = "추적이 중지되었습니다."
        } catch {
            guard activeRunID == runID else { return }
            resetTrackingSession()
            status = "추적을 시작하지 못했습니다."
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        activeRunID = nil
        isRunning = false
        resetTrackingSession()
        trackedDrums.values.forEach { $0.entity.removeFromParent() }
        trackedDrums.removeAll()
        trackedObjectCount = 0
        previousTips.removeAll()
        lastHitAt.removeAll()
        isImmersiveSpaceOpen = false
        status = "참조 물체를 찾는 중…"
    }

    private func resetTrackingSession() {
        session?.stop()
        session = nil
        handTracking = nil
        objectTracking = nil
    }

    private func loadReferenceObjects() async throws -> [ReferenceObject] {
        // Xcode can either preserve the ReferenceObjects folder or flatten its
        // contents into the app bundle. Support both layouts so adding a file by
        // drag-and-drop and regenerating with XcodeGen behave the same way.
        let nestedURLs = Bundle.main.urls(
            forResourcesWithExtension: "referenceobject",
            subdirectory: "ReferenceObjects"
        ) ?? []
        let rootURLs = Bundle.main.urls(
            forResourcesWithExtension: "referenceobject",
            subdirectory: nil
        ) ?? []
        let urls = Array(Set(nestedURLs + rootURLs)).sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }

        return try await withThrowingTaskGroup(of: ReferenceObject.self) { group in
            for url in urls { group.addTask { try await ReferenceObject(from: url) } }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }

    private func consumeObjectUpdates(
        from provider: ObjectTrackingProvider,
        root: Entity,
        runID: UUID
    ) async {
        for await update in provider.anchorUpdates {
            guard activeRunID == runID, !Task.isCancelled else { break }
            let anchor = update.anchor
            switch update.event {
            case .added:
                trackedDrums.removeValue(forKey: anchor.id)?.entity.removeFromParent()
                let drum = await TrackedDrum(anchor: anchor)
                trackedDrums[anchor.id] = drum
                root.addChild(drum.entity)
            case .updated:
                trackedDrums[anchor.id]?.update(anchor: anchor)
            case .removed:
                trackedDrums.removeValue(forKey: anchor.id)?.entity.removeFromParent()
            }
            let activeDrums = trackedDrums.values.filter(\.isTracked)
            trackedObjectCount = activeDrums.count
            if let trackedDrum = activeDrums.first {
                status = "✓ \(trackedDrum.displayName) 인식 완료 — 위를 두드려 보세요"
            } else {
                status = "참조 물체를 찾는 중…"
            }
        }
    }

    private func consumeHandUpdates(from provider: HandTrackingProvider, runID: UUID) async {
        for await update in provider.anchorUpdates {
            guard activeRunID == runID, !Task.isCancelled else { break }
            let hand = update.anchor
            guard hand.isTracked,
                  let skeleton = hand.handSkeleton else { continue }

            let joint = skeleton.joint(.indexFingerTip)
            guard joint.isTracked else { continue }

            let transform = hand.originFromAnchorTransform * joint.anchorFromJointTransform
            let current = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            defer { previousTips[hand.chirality] = current }
            guard let previous = previousTips[hand.chirality] else { continue }

            for drum in trackedDrums.values where drum.isTracked {
                if let intensity = drum.hitIntensity(from: previous, to: current) {
                    let now = ContinuousClock.now
                    if let last = lastHitAt[drum.id], now - last < .milliseconds(100) { continue }
                    lastHitAt[drum.id] = now
                    drum.play(intensity: intensity)
                }
            }
        }
    }
}

enum DrumError: LocalizedError {
    case unsupportedDevice, missingReferenceObjects
    var errorDescription: String? {
        switch self {
        case .unsupportedDevice: "이 기기는 Object Tracking 또는 Hand Tracking을 지원하지 않습니다."
        case .missingReferenceObjects: "추적 모델이 없습니다. ReferenceObjects 폴더의 .referenceobject 파일을 확인한 뒤 다시 빌드하세요."
        }
    }
}
