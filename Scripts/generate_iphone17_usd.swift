#!/usr/bin/env swift

import Foundation

struct Point3 {
    let x: Double
    let y: Double
    let z: Double
}

func number(_ value: Double) -> String {
    String(format: "%.7f", locale: Locale(identifier: "en_US_POSIX"), value)
}

func roundedBox(
    name: String,
    width: Double,
    depth: Double,
    height: Double,
    cornerRadius: Double,
    center: Point3,
    material: String,
    segmentsPerCorner: Int = 5
) -> String {
    let halfWidth = width / 2
    let halfHeight = height / 2
    let centers = [
        (halfWidth - cornerRadius, halfHeight - cornerRadius, 0.0),
        (-halfWidth + cornerRadius, halfHeight - cornerRadius, 90.0),
        (-halfWidth + cornerRadius, -halfHeight + cornerRadius, 180.0),
        (halfWidth - cornerRadius, -halfHeight + cornerRadius, 270.0)
    ]

    var perimeter: [(Double, Double)] = []
    for (centerX, centerZ, startDegrees) in centers {
        for step in 0..<segmentsPerCorner {
            let fraction = Double(step) / Double(segmentsPerCorner)
            let angle = (startDegrees + 90.0 * fraction) * .pi / 180.0
            perimeter.append((
                centerX + cornerRadius * cos(angle),
                centerZ + cornerRadius * sin(angle)
            ))
        }
    }

    let topY = center.y + depth / 2
    let bottomY = center.y - depth / 2
    let top = perimeter.map { Point3(x: center.x + $0.0, y: topY, z: center.z + $0.1) }
    let bottom = perimeter.map { Point3(x: center.x + $0.0, y: bottomY, z: center.z + $0.1) }
    let points = top + bottom
    let count = perimeter.count

    var faceCounts = [count, count]
    faceCounts.append(contentsOf: Array(repeating: 4, count: count))

    var indices = Array((0..<count).reversed())
    indices.append(contentsOf: (0..<count).map { count + $0 })
    for index in 0..<count {
        let next = (index + 1) % count
        indices.append(contentsOf: [index, next, count + next, count + index])
    }

    let pointText = points
        .map { "(\(number($0.x)), \(number($0.y)), \(number($0.z)))" }
        .joined(separator: ", ")
    let countsText = faceCounts.map(String.init).joined(separator: ", ")
    let indicesText = indices.map(String.init).joined(separator: ", ")

    return """
        def Mesh "\(name)" (
            apiSchemas = ["MaterialBindingAPI"]
        )
        {
            uniform bool doubleSided = 1
            int[] faceVertexCounts = [\(countsText)]
            int[] faceVertexIndices = [\(indicesText)]
            point3f[] points = [\(pointText)]
            uniform token subdivisionScheme = "none"
            rel material:binding = </iPhone17Black/Materials/\(material)>
        }
    """
}

func cylinder(
    name: String,
    radius: Double,
    height: Double,
    center: Point3,
    material: String
) -> String {
    """
        def Cylinder "\(name)" (
            apiSchemas = ["MaterialBindingAPI"]
        )
        {
            uniform token axis = "Y"
            double height = \(number(height))
            double radius = \(number(radius))
            double3 xformOp:translate = (\(number(center.x)), \(number(center.y)), \(number(center.z)))
            uniform token[] xformOpOrder = ["xformOp:translate"]
            rel material:binding = </iPhone17Black/Materials/\(material)>
        }
    """
}

func cube(
    name: String,
    size: Point3,
    center: Point3,
    material: String
) -> String {
    """
        def Cube "\(name)" (
            apiSchemas = ["MaterialBindingAPI"]
        )
        {
            double size = 1
            double3 xformOp:scale = (\(number(size.x)), \(number(size.y)), \(number(size.z)))
            double3 xformOp:translate = (\(number(center.x)), \(number(center.y)), \(number(center.z)))
            uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:scale"]
            rel material:binding = </iPhone17Black/Materials/\(material)>
        }
    """
}

func material(
    name: String,
    color: Point3,
    metallic: Double,
    roughness: Double,
    clearcoat: Double = 0
) -> String {
    """
            def Material "\(name)"
            {
                token outputs:surface.connect = </iPhone17Black/Materials/\(name)/Surface.outputs:surface>

                def Shader "Surface"
                {
                    uniform token info:id = "UsdPreviewSurface"
                    color3f inputs:diffuseColor = (\(number(color.x)), \(number(color.y)), \(number(color.z)))
                    float inputs:metallic = \(number(metallic))
                    float inputs:roughness = \(number(roughness))
                    float inputs:clearcoat = \(number(clearcoat))
                    token outputs:surface
                }
            }
    """
}

let bodyDepth = 0.00795
let bodyTop = bodyDepth / 2
let cameraBumpDepth = 0.00235
let cameraBumpTop = bodyTop + cameraBumpDepth

let scene = """
#usda 1.0
(
    defaultPrim = "iPhone17Black"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "iPhone17Black" (
    kind = "component"
)
{
\(roundedBox(
    name: "Body",
    width: 0.0715,
    depth: bodyDepth,
    height: 0.1496,
    cornerRadius: 0.0105,
    center: Point3(x: 0, y: 0, z: 0),
    material: "Body"
))

\(roundedBox(
    name: "CameraPlateau",
    width: 0.0235,
    depth: cameraBumpDepth,
    height: 0.0480,
    cornerRadius: 0.0100,
    center: Point3(x: -0.0192, y: bodyTop + cameraBumpDepth / 2, z: 0.0415),
    material: "CameraPlateau",
    segmentsPerCorner: 4
))

\(cylinder(
    name: "UpperLensRing",
    radius: 0.00825,
    height: 0.0030,
    center: Point3(x: -0.0192, y: cameraBumpTop + 0.0015, z: 0.0520),
    material: "LensRing"
))

\(cylinder(
    name: "UpperLensGlass",
    radius: 0.00655,
    height: 0.0009,
    center: Point3(x: -0.0192, y: cameraBumpTop + 0.00325, z: 0.0520),
    material: "LensGlass"
))

\(cylinder(
    name: "LowerLensRing",
    radius: 0.00825,
    height: 0.0030,
    center: Point3(x: -0.0192, y: cameraBumpTop + 0.0015, z: 0.0310),
    material: "LensRing"
))

\(cylinder(
    name: "LowerLensGlass",
    radius: 0.00655,
    height: 0.0009,
    center: Point3(x: -0.0192, y: cameraBumpTop + 0.00325, z: 0.0310),
    material: "LensGlass"
))

\(cylinder(
    name: "Flash",
    radius: 0.00325,
    height: 0.0009,
    center: Point3(x: 0.0040, y: bodyTop + 0.00045, z: 0.0475),
    material: "Flash"
))

\(cylinder(
    name: "Microphone",
    radius: 0.00115,
    height: 0.0007,
    center: Point3(x: 0.0040, y: bodyTop + 0.00035, z: 0.0368),
    material: "LensGlass"
))

\(cube(
    name: "PowerButton",
    size: Point3(x: 0.0011, y: 0.0054, z: 0.0180),
    center: Point3(x: 0.03625, y: 0, z: 0.0180),
    material: "Frame"
))

\(cube(
    name: "CameraControl",
    size: Point3(x: 0.0010, y: 0.0054, z: 0.0120),
    center: Point3(x: 0.03620, y: 0, z: -0.0420),
    material: "Frame"
))

\(cube(
    name: "ActionButton",
    size: Point3(x: 0.0010, y: 0.0054, z: 0.0080),
    center: Point3(x: -0.03620, y: 0, z: 0.0520),
    material: "Frame"
))

\(cube(
    name: "VolumeUp",
    size: Point3(x: 0.0010, y: 0.0054, z: 0.0120),
    center: Point3(x: -0.03620, y: 0, z: 0.0300),
    material: "Frame"
))

\(cube(
    name: "VolumeDown",
    size: Point3(x: 0.0010, y: 0.0054, z: 0.0120),
    center: Point3(x: -0.03620, y: 0, z: 0.0130),
    material: "Frame"
))

    def Scope "Materials"
    {
\(material(name: "Body", color: Point3(x: 0.035, y: 0.038, z: 0.042), metallic: 0.25, roughness: 0.32))
\(material(name: "Frame", color: Point3(x: 0.020, y: 0.022, z: 0.025), metallic: 0.70, roughness: 0.20))
\(material(name: "CameraPlateau", color: Point3(x: 0.018, y: 0.020, z: 0.023), metallic: 0.20, roughness: 0.26))
\(material(name: "LensRing", color: Point3(x: 0.008, y: 0.009, z: 0.011), metallic: 0.70, roughness: 0.13))
\(material(name: "LensGlass", color: Point3(x: 0.002, y: 0.005, z: 0.012), metallic: 0.05, roughness: 0.06, clearcoat: 0.85))
\(material(name: "Flash", color: Point3(x: 0.82, y: 0.80, z: 0.70), metallic: 0.0, roughness: 0.28, clearcoat: 0.35))
    }
}
"""

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "TrainingAssets/iPhone17/iPhone17Black-LowPoly.usda")
try scene.write(to: outputURL, atomically: true, encoding: .utf8)
print("Generated \(outputURL.path)")
