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

//// MARK: - AngleMeasurement
//
//struct AngleMeasurement {
//    let id: UUID
//    let entity: Entity
//    let pivotPosition: SIMD3<Float>
//    let firstRayPosition: SIMD3<Float>
//    let secondRayPosition: SIMD3<Float>
//    let angleInDegrees: Float
//    let timestamp: Date
//    
//    init(pivot: SIMD3<Float>, firstRay: SIMD3<Float>, secondRay: SIMD3<Float>) {
//        self.id = UUID()
//        self.pivotPosition = pivot
//        self.firstRayPosition = firstRay
//        self.secondRayPosition = secondRay
//        self.timestamp = Date()
//        
//        // Calculate angle
//        let vector1 = normalize(firstRay - pivot)
//        let vector2 = normalize(secondRay - pivot)
//        let dotProduct = dot(vector1, vector2)
//        let angleRadians = acos(max(-1.0, min(1.0, dotProduct)))
//        self.angleInDegrees = angleRadians * 180.0 / .pi
//        
//        // Create container
//        let containerEntity = Entity()
//        
//        // Create first ray line
//        let ray1Entity = Self.createRayLine(from: pivot, to: firstRay, color: .systemPurple)
//        
//        // Create second ray line
//        let ray2Entity = Self.createRayLine(from: pivot, to: secondRay, color: .systemPurple)
//        
//        // Create pivot point sphere
//        let pivotEntity = Entity()
//        pivotEntity.position = pivot
//        pivotEntity.components.set(ModelComponent(
//            mesh: .generateSphere(radius: 0.008),
//            materials: [SimpleMaterial(color: .systemOrange, roughness: 0.2, isMetallic: false)]
//        ))
//        
//        // Create arc to visualize angle
//        let arcEntity = Self.createAngleArc(
//            pivot: pivot,
//            firstRay: firstRay,
//            secondRay: secondRay,
//            angleRadians: angleRadians
//        )
//        
//        // Create text label
//        let textEntity = Entity()
//        let labelPosition = pivot + SIMD3<Float>(0, 0.05, 0)
//        textEntity.position = labelPosition
//        
//        let angleText = String(format: "%.1f°", angleInDegrees)
//        let textMesh = MeshResource.generateText(
//            angleText,
//            extrusionDepth: 0.001,
//            font: .systemFont(ofSize: 0.025, weight: .bold),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byWordWrapping
//        )
//        
//        textEntity.components.set(ModelComponent(
//            mesh: textMesh,
//            materials: [SimpleMaterial(color: .systemYellow, roughness: 0.1, isMetallic: false)]
//        ))
//        textEntity.components.set(BillboardComponent())
//        
//        // Assemble
//        containerEntity.addChild(ray1Entity)
//        containerEntity.addChild(ray2Entity)
//        containerEntity.addChild(pivotEntity)
//        containerEntity.addChild(arcEntity)
//        containerEntity.addChild(textEntity)
//        
//        self.entity = containerEntity
//    }
//    
//    private static func createRayLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor) -> Entity {
//        let lineEntity = Entity()
//        let distance = simd.distance(start, end)
//        let center = (start + end) / 2
//        
//        lineEntity.position = center
//        lineEntity.components.set(ModelComponent(
//            mesh: .generateBox(
//                width: 0.004,
//                height: 0.004,
//                depth: distance,
//                cornerRadius: 0.001
//            ),
//            materials: [SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)]
//        ))
//        
//        lineEntity.look(at: start, from: center, relativeTo: nil)
//        lineEntity.components.set(OpacityComponent(opacity: 0.9))
//        
//        return lineEntity
//    }
//    
//    private static func createAngleArc(
//        pivot: SIMD3<Float>,
//        firstRay: SIMD3<Float>,
//        secondRay: SIMD3<Float>,
//        angleRadians: Float
//    ) -> Entity {
//        let arcEntity = Entity()
//        
//        // Create a simple arc visualization using multiple small spheres
//        let arcRadius: Float = 0.03
//        let numSegments = max(3, Int(angleRadians * 10))
//        
//        let vector1 = normalize(firstRay - pivot)
//        let vector2 = normalize(secondRay - pivot)
//        
//        for i in 0...numSegments {
//            let t = Float(i) / Float(numSegments)
//            let angle = angleRadians * t
//            
//            // Create rotation axis
//            let rotationAxis = normalize(cross(vector1, vector2))
//            
//            // Rotate vector1 around the axis
//            let rotation = simd_quatf(angle: angle, axis: rotationAxis)
//            let direction = rotation.act(vector1)
//            
//            let pointPosition = pivot + direction * arcRadius
//            
//            let sphere = Entity()
//            sphere.position = pointPosition
//            sphere.components.set(ModelComponent(
//                mesh: .generateSphere(radius: 0.003),
//                materials: [SimpleMaterial(color: .systemYellow, roughness: 0.3, isMetallic: false)]
//            ))
//            
//            arcEntity.addChild(sphere)
//        }
//        
//        return arcEntity
//    }
//}

// MARK: - MyEntities
@MainActor
class MyEntities {
    let root = Entity()
    var fingerTips: [HandAnchor.Chirality: Entity]
    let currentLine = Entity() // Current active measurement line
    var resultBoard: Entity?
    
    // Storage for placed measurements
    private var placedMeasurements: [MeasurementLine] = []
    
//    private var angleFirstRayStart: SIMD3<Float>?  // Pivot point (left hand)
//    private var angleFirstRayEnd: SIMD3<Float>?    // First ray endpoint (right hand)
//    private var angleReferenceEntity: Entity?
//    private var tempAngleEntities: [Entity] = []
//    
//    var angleCount: Int {
//        return placedAngles.count
//    }
    
    // Settings
    var maxStoredMeasurements: Int = 20
    
//    // MARK: - Constants
//    
//    private static let offscreenPosition = SIMD3<Float>(-1000, -1000, -1000)
//    private static let minMeasurementDistance: Float = 0.005
//    private static let trackingThreshold: Float = -999
    
    // MARK: - Initialization
    
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
        
        // Initially hide the root
        root.isEnabled = false
    }
    
    func add(_ resultBoardEntity: Entity) {
        resultBoard = resultBoardEntity
        root.addChild(resultBoardEntity)
    }
    
//    func update(for mode: GestureMode = .measure) {
    //sdound
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
        
//        guard isTracked(leftPos), isTracked(rightPos) else {
//            hideCurrentLineAndBoard()
//            return
//        }
//        
//        switch mode {
//        case .measure, .angle:
//            updateMeasurementLine(leftPos: leftPos, rightPos: rightPos, mode: mode)
//        case .annotate, .none, .drag, .rotate, .scale, .crop:
//            hideCurrentLineAndBoard()
//        }
//        
//        updateArrowOrientations()
//    }
//    
//    // MARK: - Angle Measurement Methods
//    
//    var hasActiveAngleReference: Bool {
//        return angleFirstRayStart != nil && angleFirstRayEnd != nil
//    }
//
//    func placeAngleReferenceLine(leftPos: SIMD3<Float>, rightPos: SIMD3<Float>) {
//        // Clear any existing reference line
//        clearAngleReference()
//        
//        // Store the STATIC reference line positions
//        angleFirstRayStart = leftPos
//        angleFirstRayEnd = rightPos
//        
//        // Create visual representation of the FIRST RAY (reference line)
//        let referenceEntity = Entity()
//        let distance = simd.distance(leftPos, rightPos)
//        let center = (leftPos + rightPos) / 2
//        
//        referenceEntity.position = center
//        referenceEntity.components.set(ModelComponent(
//            mesh: .generateBox(
//                width: 0.005,
//                height: 0.005,
//                depth: distance,
//                cornerRadius: 0.001
//            ),
//            materials: [SimpleMaterial(color: .systemBlue, roughness: 0.2, isMetallic: false)]
//        ))
//        
//        referenceEntity.look(at: leftPos, from: center, relativeTo: nil)
//        referenceEntity.components.set(OpacityComponent(opacity: 0.9))
//        
//        // Add markers at endpoints
//        let pivotMarker = Entity()
//        pivotMarker.position = leftPos
//        pivotMarker.components.set(ModelComponent(
//            mesh: .generateSphere(radius: 0.012),
//            materials: [SimpleMaterial(color: .systemRed, roughness: 0.2, isMetallic: false)]
//        ))
//        
//        let endMarker = Entity()
//        endMarker.position = rightPos
//        endMarker.components.set(ModelComponent(
//            mesh: .generateSphere(radius: 0.008),
//            materials: [SimpleMaterial(color: .systemBlue, roughness: 0.2, isMetallic: false)]
//        ))
//        
//        let container = Entity()
//        container.addChild(referenceEntity)
//        container.addChild(pivotMarker)
//        container.addChild(endMarker)
//        
//        root.addChild(container)
//        angleReferenceEntity = container
//        tempAngleEntities.append(container)
//        
//        playSystemClick(1)
//        print("🔵 First ray placed - Pivot: \(leftPos), Ray end: \(rightPos)")
//    }
//
//    func completeAngleWithRightHand(rightPos: SIMD3<Float>) {
//        guard let pivot = angleFirstRayStart,
//              let firstRayEnd = angleFirstRayEnd else {
//            print("⚠️ No reference line set")
//            return
//        }
//        
//        let angle = AngleMeasurement(
//            pivot: pivot,
//            firstRay: firstRayEnd,
//            secondRay: rightPos
//        )
//        
//        root.addChild(angle.entity)
//        placedAngles.append(angle)
//        
//        clearAngleReference()
//        
//        if placedAngles.count > maxStoredMeasurements {
//            let oldest = placedAngles.removeFirst()
//            oldest.entity.removeFromParent()
//        }
//        
//        playSystemClick(1)
//        print("✅ Angle measurement complete: \(String(format: "%.1f°", angle.angleInDegrees))")
//    }
//
//    func clearAngleReference() {
//        angleFirstRayStart = nil
//        angleFirstRayEnd = nil
//        angleReferenceEntity?.removeFromParent()
//        angleReferenceEntity = nil
//        clearTempAngleEntities()
//    }
//
//    private func clearTempAngleEntities() {
//        tempAngleEntities.forEach { $0.removeFromParent() }
//        tempAngleEntities.removeAll()
//    }
//
//    func removeLastAngle() {
//        if hasActiveAngleReference {
//            clearAngleReference()
//            playSystemClick(2)
//            print("❌ Cancelled angle reference line")
//            return
//        }
//        
//        guard let lastAngle = placedAngles.popLast() else {
//            print("No angles to remove")
//            return
//        }
//        lastAngle.entity.removeFromParent()
//        playSystemClick(2)
//        print("🗑️ Last angle removed")
//    }
//
//    func clearAllAngles() {
//        clearAngleReference()
//        placedAngles.forEach { $0.entity.removeFromParent() }
//        placedAngles.removeAll()
//        print("🧹 All angles cleared")
//    }
//
//    func getAllAngles() -> [AngleMeasurement] {
//        return placedAngles
//    }
//
//    func getAngleResultString() -> String {
//        if hasActiveAngleReference {
//            return "Right pinch to place second ray ➡️"
//        }
//        
//        let count = placedAngles.count
//        if count == 0 {
//            return "Left pinch: define first ray"
//        } else if count == 1 {
//            return "1 angle measured"
//        } else {
//            return "\(count) angles measured"
//        }
//    }
//
//    private func setAngleVisibility(_ isVisible: Bool) {
//        placedAngles.forEach { $0.entity.isEnabled = isVisible }
//        tempAngleEntities.forEach { $0.isEnabled = isVisible }
//    }
//    
//    // MARK: - Measurement Management
//    
//    func placeMeasurement() {
//        guard let leftPos = fingerTips[.left]?.position,
//              let rightPos = fingerTips[.right]?.position else {
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
        
//        guard isTracked(leftPos), isTracked(rightPos) else {
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        guard isLeftTracked && isRightTracked else {
            print("Cannot place measurement: hands not tracked")
            return
        }
        
        let length = distance(leftPos, rightPos)
//        guard length > Self.minMeasurementDistance else {
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
    
//    func getMeasurementStats() -> (count: Int, average: Float, min: Float, max: Float)? {
//        guard !placedMeasurements.isEmpty else { return nil }
//        
//        let distances = placedMeasurements.map { $0.distance }
//        let sum = distances.reduce(0, +)
//        let average = sum / Float(distances.count)
//        let min = distances.min() ?? 0
//        let max = distances.max() ?? 0
//        
//        return (count: distances.count, average: average, min: min, max: max)
//    }
//    
//    // MARK: - Annotation Management
//    
//    func addAnnotation(_ annotation: AnnotationNote) {
//        root.addChild(annotation.entity)
//        annotations[annotation.id] = annotation.entity
//        print("Added annotation to scene: \(annotation.id)")
//    }
//    
//    func removeAnnotation(id: UUID) {
//        guard let entity = annotations[id] else {
//            print("Annotation not found: \(id)")
//            return
//        }
//        entity.removeFromParent()
//        annotations.removeValue(forKey: id)
//        print("Removed annotation from scene: \(id)")
//    }
//    
//    func clearAllAnnotations() {
//        annotations.values.forEach { $0.removeFromParent() }
//        annotations.removeAll()
//        print("Cleared all annotations from scene")
//    }
//    
//    var sceneAnnotationCount: Int {
//        return annotations.count
//    }
//    
//    // MARK: - Mode-Based Visibility
//    
//    func updateVisibilityForMode(_ mode: GestureMode) {
//        switch mode {
//        case .measure:
//            setMeasurementVisibility(true)
//            setAngleVisibility(false)
//            setFingerTipVisibility(true)
//            
//        case .angle:
//            setMeasurementVisibility(false)
//            setAngleVisibility(true)
//            setFingerTipVisibility(true)
//            
//        case .annotate:
//            setMeasurementVisibility(false)
//            setAngleVisibility(false)
//            setFingerTipVisibility(true)
//            
//        case .none, .drag, .rotate, .scale, .crop:
//            setMeasurementVisibility(false)
//            setAngleVisibility(false)
//            setFingerTipVisibility(false)
//        }
//    }
//    
//    // MARK: - Display and Formatting
//    
//    func getResultString() -> String {
//        guard let leftPos = fingerTips[.left]?.position,
//              let rightPos = fingerTips[.right]?.position else {
//            return "No entities"
//        }
//        
//        guard isTracked(leftPos), isTracked(rightPos) else {
    // MARK: - Formatting and Display
    
    func getResultString() -> String {
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
}
