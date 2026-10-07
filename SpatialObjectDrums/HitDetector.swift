import Foundation
import simd

struct HitDetector: Sendable {
    let boundsMin: SIMD3<Float>
    let boundsMax: SIMD3<Float>
    let hitPlaneY: Float

    func intensity(
        from previous: SIMD3<Float>,
        to current: SIMD3<Float>,
        elapsedSeconds: Float,
        tuning: DrumTuning
    ) -> Float? {
        guard elapsedSeconds > 0,
            elapsedSeconds <= tuning.maximumSampleInterval
        else { return nil }

        let movement = current - previous
        let distance = simd_length(movement)
        guard distance <= tuning.maximumSampleDistance else { return nil }

        let downwardDistance = previous.y - current.y
        guard previous.y > hitPlaneY,
            current.y <= hitPlaneY,
            downwardDistance > .ulpOfOne
        else { return nil }

        let crossingFraction = (previous.y - hitPlaneY) / downwardDistance
        let crossing = previous + movement * crossingFraction
        guard crossing.x >= boundsMin.x, crossing.x <= boundsMax.x,
            crossing.z >= boundsMin.z, crossing.z <= boundsMax.z
        else { return nil }

        let downwardSpeed = downwardDistance / elapsedSeconds
        guard downwardSpeed >= tuning.minimumStrikeSpeed else { return nil }
        let speedRange = max(tuning.maximumStrikeSpeed - tuning.minimumStrikeSpeed, .ulpOfOne)
        return min(max((downwardSpeed - tuning.minimumStrikeSpeed) / speedRange, 0), 1)
    }
}
