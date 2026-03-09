//
//  MyEntities.swift
//  3D Microscopy
//
//  Created by FutureLab XR2 on 7/9/25.
//
import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import AudioToolbox

// Structure to hold measurement data with text label
struct MeasurementLine {
    let id: UUID
    let entity: Entity // Container for both line and text
    let lineEntity: Entity // The actual line
    let textEntity: Entity // The measurement text
    let leftPosition: SIMD3<Float>
    let rightPosition: SIMD3<Float>
    let distance: Float
    let timestamp: Date
    
    init(leftPos: SIMD3<Float>, rightPos: SIMD3<Float>) {
        self.id = UUID()
        self.leftPosition = leftPos
        self.rightPosition = rightPos
        self.distance = simd.distance(leftPos, rightPos)
        self.timestamp = Date()
        
        // Create container entity
        let containerEntity = Entity()
        
        // Create the line entity
        let centerPosition = (leftPos + rightPos) / 2
        let lineEntity = Entity()
        lineEntity.position = centerPosition
        lineEntity.components.set(ModelComponent(
            mesh: .generateBox(
                width: 0.003,
                height: 0.003,
                depth: distance,
                cornerRadius: 0.001
            ),
            materials: [SimpleMaterial(color: .white, roughness: 0.2, isMetallic: false)]
        ))
        lineEntity.look(at: leftPos, from: centerPosition, relativeTo: nil)
        lineEntity.components.set(OpacityComponent(opacity: 0.8))
        
        // Create text entity for the measurement
        let textEntity = Entity()
        textEntity.position = centerPosition + SIMD3<Float>(0, 0.05, 0) // Position above the line
        
        // Create text component with measurement
        let formattedDistance = Self.formatDistance(distance)
        let textMesh = MeshResource.generateText(
            formattedDistance,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.02),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        textEntity.components.set(ModelComponent(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .white, roughness: 0.1, isMetallic: false)]
        ))
        
        // Make text always face the user
        textEntity.components.set(BillboardComponent())
        
        // Add both to container
        containerEntity.addChild(lineEntity)
        containerEntity.addChild(textEntity)
        
        self.entity = containerEntity
        self.lineEntity = lineEntity
        self.textEntity = textEntity
    }
    
    private static func formatDistance(_ distance: Float) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        if distance < 0.01 {
            return "\(formatter.string(from: NSNumber(value: distance * 1000)) ?? "0.00")mm"
        } else if distance < 1.0 {
            return "\(formatter.string(from: NSNumber(value: distance * 100)) ?? "0.00")cm"
        } else {
            return "\(formatter.string(from: NSNumber(value: distance)) ?? "0.00")m"
        }
    }
    
}

@MainActor
class MyEntities {
    let root = Entity()
    var fingerTips: [HandAnchor.Chirality: Entity]
    let currentLine = Entity() // Current active measurement line
    var resultBoard: Entity?
    
    // Storage for placed measurements
    private var placedMeasurements: [MeasurementLine] = []
    
    // Settings
    var maxStoredMeasurements: Int = 20 // Limit to prevent performance issues
    
    // MARK: - Angle Measurement storage properties
    struct AngleMeasurement {
        let id: UUID
        let container: Entity
        let degrees: Float
        let timestamp: Date

        init(container: Entity, degrees: Float) {
            self.id = UUID()
            self.container = container
            self.degrees = degrees
            self.timestamp = Date()
        }
    }
    private var angleFirstLine: (start: SIMD3<Float>, end: SIMD3<Float>)?
    private var angleSecondLine: (start: SIMD3<Float>, end: SIMD3<Float>)?
    private var angleContainer = Entity()
    private var angleArcEntity: Entity?
    private var angleSphere: Entity?
    var isAngleMode = false
    private var angleTextEntity: Entity?
    
    private var placedAngles: [AngleMeasurement] = []
    var maxStoredAngles: Int = 20
    
    // MARK: - init
    init() {
        // Create arrow-shaped finger tip indicators
        let leftTip = Self.createArrowIndicator(color: .systemPurple)
        let rightTip = Self.createArrowIndicator(color: .systemPurple)
        
        // Position them off-screen initially so they don't appear at origin
        leftTip.position = SIMD3<Float>(-1000, -1000, -1000)
        rightTip.position = SIMD3<Float>(-1000, -1000, -1000)
        
        fingerTips = [
            .left: leftTip,
            .right: rightTip
        ]
        
        fingerTips.values.forEach { root.addChild($0) }
        
        // Make the current line more visible but initially hidden (yellow for active)
        currentLine.components.set(OpacityComponent(opacity: 0.9))
        currentLine.isEnabled = false
        root.addChild(currentLine)
        
        root.addChild(angleContainer)
        
        // Initially hide the root
        root.isEnabled = false
    }
    
    func add(_ resultBoardEntity: Entity) {
        resultBoard = resultBoardEntity
        root.addChild(resultBoardEntity)
    }
    
    //sound
    func playSystemClick(_ num: Int = 1) {
        if(num == 1){
            AudioServicesPlaySystemSound(1104) // 1104 = Tock (keyboard tap-like click)
        } else if(num == 2){
            AudioServicesPlaySystemSound(1155)
        }
    }

    func update() {
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else { return }
        
        // Check if both hands are actually tracked (not at initial position)
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        // Only show measurement when both hands are tracked
        guard isLeftTracked && isRightTracked else {
            currentLine.isEnabled = false
            resultBoard?.isEnabled = false
            return
        }
        
        let centerPosition = (leftPos + rightPos) / 2
        let length = distance(leftPos, rightPos)
        
        // Only show the line if there's a meaningful distance
        if length > 0.005 { // Increased threshold
            currentLine.position = centerPosition
            currentLine.components.set(ModelComponent(
                mesh: .generateBox(
                    width: 0.003,
                    height: 0.003,
                    depth: length,
                    cornerRadius: 0.001
                ),
                materials: [SimpleMaterial(color: .systemPurple, roughness: 0.2, isMetallic: false)]
            ))
            
            currentLine.look(at: leftPos, from: centerPosition, relativeTo: nil)
            currentLine.isEnabled = true
            resultBoard?.isEnabled = true
        } else {
            currentLine.isEnabled = false
            resultBoard?.isEnabled = false
        }
        
        // Position the result board above the center point
        resultBoard?.setPosition(centerPosition + SIMD3<Float>(0, 0.01, 0), relativeTo: nil)
        
        // Update arrow orientations to point toward each other
        updateArrowOrientations()
    }
    
    // MARK: - Multiple Measurements Management
    
    /// Places the current measurement as a permanent line WITH TEXT LABEL
    func placeMeasurement() {
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else {
            print("Cannot place measurement: fingertip entities not found")
            return
        }
        
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        guard isLeftTracked && isRightTracked else {
            print("Cannot place measurement: hands not tracked")
            return
        }
        
        let length = distance(leftPos, rightPos)
        guard length > 0.005 else {
            print("Cannot place measurement: distance too small (\(length)m)")
            return
        }
        
        // Create new measurement with text label
        let measurement = MeasurementLine(leftPos: leftPos, rightPos: rightPos)

        // Add to scene
        root.addChild(measurement.entity)
        
        // Store measurement
        placedMeasurements.append(measurement)
        
        // Remove oldest if we exceed limit
        if placedMeasurements.count > maxStoredMeasurements {
            let oldest = placedMeasurements.removeFirst()
            oldest.entity.removeFromParent()
        }
        
        //play add sound
        playSystemClick(1)
       
    }
    
    /// Removes the most recent measurement
    func removeLastMeasurement() {
        guard let lastMeasurement = placedMeasurements.popLast() else {
            print("No measurements to remove")
            return
        }
        lastMeasurement.entity.removeFromParent()
        
        //play delete sound
        playSystemClick(2)
    
    }
    
    /// Clears all placed measurements
    func clearAllMeasurements() {
        placedMeasurements.forEach { $0.entity.removeFromParent() }
        placedMeasurements.removeAll()
        print("Cleared all \(placedMeasurements.count) measurements")
    }
    
    /// Returns all current measurements
    func getAllMeasurements() -> [MeasurementLine] {
        return placedMeasurements
    }
    
    /// Gets measurement count
    var measurementCount: Int {
        return placedMeasurements.count
    }
    
    func showMeasurements() {
        for measurement in placedMeasurements {
            measurement.entity.isEnabled = true
        }

        for angle in placedAngles {
            angle.container.isEnabled = false
        }
    }
    // MARK: - Angle Placement Logic

    func placeAnglePoint() {
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else { return }

        let leftPos = leftTip.position
        let rightPos = rightTip.position

        let isLeftTracked = leftPos.x > -999
        let isRightTracked = rightPos.x > -999

        guard isLeftTracked && isRightTracked else { return }

        if angleFirstLine == nil {
            // Ensure previous angle is completely cleared
            angleContainer.children.forEach { $0.removeFromParent() }
            angleArcEntity = nil
            angleSphere = nil
            angleSecondLine = nil

            // FIRST LINE
            angleFirstLine = (leftPos, rightPos)

            createAngleLine(from: leftPos, to: rightPos)
            createAnchorSphere(at: rightPos)

            playSystemClick(1)
            return
        }

        if angleSecondLine == nil {
            // SECOND LINE STARTS AT END OF FIRST
            guard let first = angleFirstLine else { return }
            angleSecondLine = (first.end, leftPos)
            createAngleLine(from: first.end, to: leftPos)
            createAngleArc()
            playSystemClick(1)
        }
    }
    
    private func createAngleLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {

        let length = distance(start, end)
        guard length > 0.005 else { return }

        let center = (start + end) / 2

        let line = Entity()
        line.position = center
        line.components.set(ModelComponent(
            mesh: .generateBox(width: 0.003,
                               height: 0.003,
                               depth: length),
            materials: [SimpleMaterial(color: .orange, roughness: 0.2, isMetallic: false)]
        ))

        line.look(at: start, from: center, relativeTo: nil)
        angleContainer.addChild(line)
    }
    
    private func createAnchorSphere(at position: SIMD3<Float>) {
        angleSphere?.removeFromParent() // protect against duplicate spheres

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.01),
            materials: [SimpleMaterial(color: .yellow,
                                       roughness: 0.2,
                                       isMetallic: false)]
        )

        sphere.position = position
        angleSphere = sphere
        angleContainer.addChild(sphere)
    }

    private func createAngleArc() {
        guard let first = angleFirstLine,
              let second = angleSecondLine else { return }

        let pivot = first.end

        // Direction vectors of the two lines
        let v1 = normalize(first.start - pivot)
        let v2 = normalize(second.end - pivot)

        // Angle calculation
        let dotProduct = simd_dot(v1, v2)
        let angle = acos(max(-1.0, min(1.0, dotProduct)))
        let degrees = angle * 180 / .pi

        // Compute plane normal
        let planeNormal = normalize(simd_cross(v1, v2))

        // If lines are nearly collinear, avoid instability
        if simd_length(planeNormal) < 0.0001 { return }

        // Tangent axis along first line
        let tangent = normalize(v1)

        // Bitangent axis within plane
        let bitangent = normalize(simd_cross(planeNormal, tangent))

        let radius: Float = 0.03
        let segments = 32

        // Remove old arc
        angleArcEntity?.removeFromParent()

        let arcContainer = Entity()

        var previousPoint: SIMD3<Float>?

        for i in 0...segments {

            let t = Float(i) / Float(segments)
            let theta = t * angle

            // Generate point in the angle plane
            let point =
                pivot +
                radius * cos(theta) * tangent +
                radius * sin(theta) * bitangent

            if let prev = previousPoint {
                let segment = makeCylinderSegment(
                    from: prev,
                    to: point,
                    radius: 0.0015,
                    color: .orange
                )
                arcContainer.addChild(segment)
            }

            previousPoint = point
        }

        angleArcEntity = arcContainer
        angleContainer.addChild(arcContainer)

        // Create angle label
        let textMesh = MeshResource.generateText(
            String(format: "%.1f°", degrees),
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.02),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        let textEntity = ModelEntity(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .orange, roughness: 0.1, isMetallic: false)]
        )
        angleTextEntity = textEntity

        textEntity.position = pivot + planeNormal * 0.03
        textEntity.components.set(BillboardComponent())

        angleContainer.addChild(textEntity)
        
        // Store completed angle - so each angle becomes permananent and can store > 1 (up to 20)
        let storedAngle = AngleMeasurement(container: angleContainer, degrees: degrees)
        placedAngles.append(storedAngle)

        if placedAngles.count > maxStoredAngles {
            let oldest = placedAngles.removeFirst()
            oldest.container.removeFromParent()
        }

        // Prepare a fresh container for the next angle
        angleContainer = Entity()
        root.addChild(angleContainer)

        // Reset state
        angleFirstLine = nil
        angleSecondLine = nil
        angleSphere = nil
        angleArcEntity = nil
        angleTextEntity = nil
    }
    
    func removeLastAngle() {
        // If user is currently creating an angle, cancel it
        if angleFirstLine != nil && angleSecondLine == nil {
            // Remove individual entities explicitly
            angleSphere?.removeFromParent()
            angleArcEntity?.removeFromParent()
            angleTextEntity?.removeFromParent()

            // Remove any remaining children (like the first line)
            angleContainer.children.forEach { $0.removeFromParent() }

            // Reset state
            angleFirstLine = nil
            angleSecondLine = nil
            angleSphere = nil
            angleArcEntity = nil
            angleTextEntity = nil

            playSystemClick(2)
            return
        }

        // Otherwise remove last stored angle
        guard let last = placedAngles.popLast() else { return }
        last.container.removeFromParent()

        playSystemClick(2)
    }
    
    func showAngles() {
        for measurement in placedMeasurements {
            measurement.entity.isEnabled = false
        }

        for angle in placedAngles {
            angle.container.isEnabled = true
        }
    }
    // MARK: - Formatting and Display
    
    func getResultString() -> String {
        if isAngleMode {
            return ""   // hide bubble during angle mode
        }
        
        // Bubble with lenght above line preview in measurement mode
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else { return "No entities" }
        
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        guard isLeftTracked && isRightTracked else {
            return "Show both hands to camera"
        }
        
        let length = distance(leftPos, rightPos)
        
        if length < 0.005 {
            return "Touch index fingers"
        }
        
        let currentMeasurement = formatDistance(length)
        let storedCount = placedMeasurements.count
        
        if storedCount > 0 {
            return "\(currentMeasurement)\n(\(storedCount) stored)"
        } else {
            return currentMeasurement
        }
    }
    
    private func formatDistance(_ length: Float) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.minimumFractionDigits = 2
        formatter.numberFormatter.maximumFractionDigits = 2
        
        // Convert to more appropriate units based on distance
        if length < 0.01 {
            // Show in millimeters for small distances
            return formatter.string(from: .init(value: Double(length * 1000), unit: UnitLength.millimeters))
        } else if length < 1.0 {
            // Show in centimeters for medium distances
            return formatter.string(from: .init(value: Double(length * 100), unit: UnitLength.centimeters))
        } else {
            // Show in meters for large distances
            return formatter.string(from: .init(value: Double(length), unit: UnitLength.meters))
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates an arrow-shaped indicator for fingertips
    private static func createArrowIndicator(color: UIColor) -> Entity {
        let arrowEntity = Entity()
        
        // Create a simple cone as arrow
        let arrow = ModelEntity(
            mesh: .generateCone(height: 0.015, radius: 0.006),
            materials: [SimpleMaterial(color: color, roughness: 0.1, isMetallic: false)]
            )
            
        arrow.orientation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
        
        arrowEntity.addChild(arrow)
        
        return arrowEntity
    }
    
    // MARK: - Statistics
    
    /// Gets summary statistics of all measurements
    func getMeasurementStats() -> (count: Int, average: Float, min: Float, max: Float)? {
        guard !placedMeasurements.isEmpty else { return nil }
        
        let distances = placedMeasurements.map { $0.distance }
        let sum = distances.reduce(0, +)
        let average = sum / Float(distances.count)
        let min = distances.min() ?? 0
        let max = distances.max() ?? 0
        
        return (count: distances.count, average: average, min: min, max: max)
    }
    
    /// Updates arrow orientations to point outward from the measurement line endpoints
    private func updateArrowOrientations() {
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else { return }
        
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
        // Only update if both hands are tracked
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        if isLeftTracked && isRightTracked {
            // Calculate the line direction vector from left to right
            let lineDirection = normalize(rightPos - leftPos)
            
            // Left arrow should point in the opposite direction (outward from line)
            let leftOutwardDirection = -lineDirection
            
            // Right arrow should point in the same direction as line (outward from line)
            let rightOutwardDirection = lineDirection
            
            // Convert direction vectors to rotations
            leftTip.orientation = orientationFromDirection(leftOutwardDirection)
            rightTip.orientation = orientationFromDirection(rightOutwardDirection)
        }
    }
    
    /// Helper function to create rotation from a direction vector
    private func orientationFromDirection(_ direction: SIMD3<Float>) -> simd_quatf {
        // Default arrow points along positive Z-axis
        let defaultDirection = SIMD3<Float>(0, 0, 1)
        
        // Calculate rotation needed to align default direction with target direction
        let normalizedDirection = normalize(direction)
        
        // Handle the case where directions are opposite
        if dot(defaultDirection, normalizedDirection) < -0.999 {
            // Directions are opposite, rotate 180 degrees around any perpendicular axis
            return simd_quatf(angle: .pi, axis: [0, 1, 0])
        }
        
        // Calculate cross product for rotation axis
        let rotationAxis = normalize(cross(defaultDirection, normalizedDirection))
        
        // Calculate angle between vectors
        let cosAngle = dot(defaultDirection, normalizedDirection)
        let angle = acos(max(-1.0, min(1.0, cosAngle)))
        
        // Create quaternion rotation
        if length(rotationAxis) > 0.001 {
            return simd_quatf(angle: angle, axis: rotationAxis)
        } else {
            // Vectors are already aligned
            return simd_quatf(angle: 0, axis: [0, 1, 0])
        }
    }
    
    private func makeCylinderSegment(from start: SIMD3<Float>, to end: SIMD3<Float>, radius: Float, color: UIColor) -> Entity {
        let dir = end - start
        let length = simd_length(dir)
        // Avoid zero-length segments
        guard length > 0.0001 else { return Entity() }

        // RealityKit cylinders are centered; position at midpoint
        let mid = (start + end) / 2

        // Generate a vertical cylinder (aligned with +Y) and then rotate into place
        let cylinder = ModelEntity(
            mesh: .generateCylinder(height: length, radius: radius),
            materials: [SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)]
        )

        cylinder.position = mid

        // Compute rotation from cylinder's default up axis (0,1,0) to desired direction
        let up = SIMD3<Float>(0, 1, 0)
        let target = normalize(dir)
        let dotVal = max(-1.0, min(1.0, simd_dot(up, target)))
        let angle = acos(dotVal)
        if angle > 0.0001 {
            let axis = simd_normalize(simd_cross(up, target))
            cylinder.orientation = simd_quatf(angle: angle, axis: axis)
        }

        return cylinder
    }
}
