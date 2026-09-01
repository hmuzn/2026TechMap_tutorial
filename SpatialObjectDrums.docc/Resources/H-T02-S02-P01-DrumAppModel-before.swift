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
            async let events: Void = consumeSessionEvents(from: session, runID: runID)
            _ = await (objects, hands, events)
            if activeRunID == runID, self.session === session {
                resetTrackingSession()
                clearTrackingContent()
                status = "추적 데이터가 종료되었습니다."
                errorMessage = "ARKit 데이터 스트림이 예기치 않게 종료되었습니다. 공간을 닫고 재시도하세요."
            }
        } catch is CancellationError {
            guard activeRunID == runID else { return }
            resetTrackingSession()
            clearTrackingContent()
            status = "추적이 중지되었습니다."
        } catch {
            guard activeRunID == runID else { return }
            resetTrackingSession()
            clearTrackingContent()
            status = "추적을 시작하지 못했습니다."
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        activeRunID = nil
        isRunning = false
        resetTrackingSession()
        clearTrackingContent()
        isImmersiveSpaceOpen = false
        status = "참조 물체를 찾는 중…"
    }

    private func clearTrackingContent() {
        trackedDrums.values.forEach { $0.entity.removeFromParent() }
        trackedDrums.removeAll()
        trackedObjectCount = 0
        previousTips.removeAll()
        lastHitAt.removeAll()
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

        var references: [ReferenceObject] = []
        for url in urls {
            var configuration = ReferenceObject.Configuration()
            configuration.highFrameRateTrackingEnabled = false
            references.append(
                try await ReferenceObject(from: url, configuration: configuration)
            )
        }
        return references
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












            case .updated:
                trackedDrums[anchor.id]?.update(anchor: anchor)
            case .removed:
                trackedDrums.removeValue(forKey: anchor.id)?.entity.removeFromParent()
                lastHitAt[anchor.id] = nil
            }
            let activeDrums = trackedDrums.values.filter(\.isTracked)
            trackedObjectCount = activeDrums.count
            if let trackedDrum = activeDrums.first {
                status = "✓ \(trackedDrum.displayName) 인식 완료 · \(activeDrums.count)개 추적 중"
            } else {
                status = "참조 물체를 찾는 중…"
            }
        }
    }

    private func consumeSessionEvents(from session: ARKitSession, runID: UUID) async {
        for await event in session.events {
            guard activeRunID == runID, !Task.isCancelled else { break }

            switch event {
            case .authorizationChanged(_, let authorizationStatus):
                guard authorizationStatus == .denied else { continue }
                status = "ARKit 권한이 중단되었습니다."
                errorMessage = "손 추적 또는 주변 공간 접근 권한이 거부되었습니다. 권한을 다시 허용한 뒤 공간을 닫고 재시도하세요."
                clearTrackingContent()
                resetTrackingSession()
                return

            case .dataProviderStateChanged(_, let newState, let error):
                if newState == .paused {
                    status = "ARKit 추적이 일시 중지되었습니다."
                } else if newState == .stopped {
                    status = "ARKit 추적이 중단되었습니다."
                    errorMessage = error?.localizedDescription
                        ?? "Object Tracking 또는 Hand Tracking Provider가 중단되었습니다. 공간을 닫고 재시도하세요."
                    clearTrackingContent()
                    resetTrackingSession()
                    return
                }

            @unknown default:
                continue
            }
        }
    }

    private func consumeHandUpdates(from provider: HandTrackingProvider, runID: UUID) async {
        for await update in provider.anchorUpdates {
            guard activeRunID == runID, !Task.isCancelled else { break }
            let hand = update.anchor
            guard hand.isTracked,
                  let skeleton = hand.handSkeleton else {
                previousTips[hand.chirality] = nil
                continue
            }

            let joint = skeleton.joint(.indexFingerTip)
            guard joint.isTracked else {
                previousTips[hand.chirality] = nil
                continue
            }

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
