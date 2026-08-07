let size = anchor.boundingBox.extents
let hitSurface = ModelEntity(
    mesh: .generateBox(size: [size.x, 0.004, size.z]),
    materials: [SimpleMaterial(color: .orange, isMetallic: false)]
)
hitSurface.position.y = anchor.boundingBox.max.y + 0.004

let inverse = entity.transformMatrix(relativeTo: nil).inverse
let previousLocal = inverse * SIMD4<Float>(previousWorld, 1)
let currentLocal = inverse * SIMD4<Float>(currentWorld, 1)
let crossedTop = previousLocal.y > bounds.max.y && currentLocal.y <= bounds.max.y

