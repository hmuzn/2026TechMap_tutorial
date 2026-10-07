import XCTest

@testable import SpatialObjectDrums

final class HitDetectorTests: XCTestCase {
    private let detector = HitDetector(
        boundsMin: [-0.15, -0.01, -0.06],
        boundsMax: [0.15, 0.01, 0.06],
        hitPlaneY: 0.02
    )
    private let tuning = DrumTuning()

    func testDownwardCrossingInsideBoundsProducesHit() {
        let intensity = detector.intensity(
            from: [0, 0.04, 0], to: [0, 0.01, 0],
            elapsedSeconds: 0.03, tuning: tuning
        )
        XCTAssertNotNil(intensity)
        XCTAssertGreaterThan(intensity ?? 0, 0)
    }

    func testUpwardMovementDoesNotProduceHit() {
        XCTAssertNil(
            detector.intensity(
                from: [0, 0.01, 0], to: [0, 0.04, 0],
                elapsedSeconds: 0.03, tuning: tuning
            ))
    }

    func testCrossingOutsideBoundsDoesNotProduceHit() {
        XCTAssertNil(
            detector.intensity(
                from: [0.3, 0.04, 0], to: [0.3, 0.01, 0],
                elapsedSeconds: 0.03, tuning: tuning
            ))
    }

    func testSlowMovementDoesNotProduceHit() {
        XCTAssertNil(
            detector.intensity(
                from: [0, 0.021, 0], to: [0, 0.019, 0],
                elapsedSeconds: 0.1, tuning: tuning
            ))
    }

    func testStaleOrTeleportingSampleDoesNotProduceHit() {
        XCTAssertNil(
            detector.intensity(
                from: [0, 0.04, 0], to: [0, 0.01, 0],
                elapsedSeconds: 0.5, tuning: tuning
            ))
        XCTAssertNil(
            detector.intensity(
                from: [0, 0.4, 0], to: [0, 0.01, 0],
                elapsedSeconds: 0.03, tuning: tuning
            ))
    }
}
