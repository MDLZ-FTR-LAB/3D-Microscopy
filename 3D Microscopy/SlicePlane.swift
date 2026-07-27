//
//  SlicePlane.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/22/26.
//  Step 1: Renders a visible grid plane normal to the index finger
//

import SwiftUI
import RealityKit
import ARKit

@MainActor
class SlicePlaneVisualizer {

    let planeEntity = Entity()
    private var gridEntity: ModelEntity?

    // Plane size in meters
    private let planeSize: Float = 0.2

    init() {
        // Create the grid plane mesh
        let mesh = MeshResource.generatePlane(
            width: planeSize,
            depth: planeSize
        )

        // Semi-transparent material
        var material = SimpleMaterial()
        material.color = .init(
            tint: UIColor.systemCyan.withAlphaComponent(0.3),
            texture: nil
        )
        material.metallic = .init(floatLiteral: 0.0)
        material.roughness = .init(floatLiteral: 0.5)

        let grid = ModelEntity(mesh: mesh, materials: [material])
        gridEntity = grid
        planeEntity.addChild(grid)

        // Add grid lines as children
        addGridLines()

        // Start hidden
        planeEntity.isEnabled = false
    }

    /// Adds visible grid lines on the plane
    private func addGridLines() {
        let lineCount = 10
        let spacing = planeSize / Float(lineCount)
        let lineThickness: Float = 0.001

        for i in 0...lineCount {
            let offset = -planeSize / 2 + spacing * Float(i)

            // Horizontal line (along X)
            let hLine = ModelEntity(
                mesh: .generateBox(
                    width: planeSize,
                    height: lineThickness,
                    depth: lineThickness
                ),
                materials: [SimpleMaterial(color: .systemCyan.withAlphaComponent(0.6), roughness: 0.5, isMetallic: false)]
            )
            hLine.position = SIMD3<Float>(0, 0.001, offset)
            planeEntity.addChild(hLine)

            // Vertical line (along Z)
            let vLine = ModelEntity(
                mesh: .generateBox(
                    width: lineThickness,
                    height: lineThickness,
                    depth: planeSize
                ),
                materials: [SimpleMaterial(color: .systemCyan.withAlphaComponent(0.6), roughness: 0.5, isMetallic: false)]
            )
            vLine.position = SIMD3<Float>(offset, 0.001, 0)
            planeEntity.addChild(vLine)
        }
    }

    // MARK: - Update each frame

    /// Call this with the index finger tip position and direction
    func update(fingerTipPosition: SIMD3<Float>, fingerDirection: SIMD3<Float>) {
        planeEntity.isEnabled = true

        // Position the plane at the fingertip
        planeEntity.position = fingerTipPosition

        // Orient the plane so its Y-axis (normal) aligns with the finger direction
        let up = SIMD3<Float>(0, 1, 0) // Plane's default normal
        let target = normalize(fingerDirection)

        // Compute rotation from default up to finger direction
        let dot = simd_dot(up, target)

        if dot < -0.999 {
            // Nearly opposite — rotate 180° around any perpendicular axis
            planeEntity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        } else if dot > 0.999 {
            // Already aligned
            planeEntity.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        } else {
            let axis = normalize(simd_cross(up, target))
            let angle = acos(max(-1.0, min(1.0, dot)))
            planeEntity.orientation = simd_quatf(angle: angle, axis: axis)
        }
    }

    /// Hide the plane
    func hide() {
        planeEntity.isEnabled = false
    }
}
