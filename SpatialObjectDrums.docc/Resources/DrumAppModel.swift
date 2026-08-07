let references = try await loadReferenceObjects()
let objectTracking = ObjectTrackingProvider(referenceObjects: references)
let handTracking = HandTrackingProvider()
try await session.run([objectTracking, handTracking])

for await update in handTracking.anchorUpdates {
    guard let skeleton = update.anchor.handSkeleton,
          let tip = skeleton.joint(.indexFingerTip),
          tip.isTracked else { continue }
    let transform = update.anchor.originFromAnchorTransform * tip.anchorFromJointTransform
    // Compare the previous and current tip positions with each tracked drum.
}

