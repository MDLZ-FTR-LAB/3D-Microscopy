//
//  MyEntities.swift
//  3D Microscopy
//
//  Created by FutureLab XR2 on 7/9/25.
//

import SwiftUI
import RealityKit
import ARKit
<<<<<<< Updated upstream
=======
import AVFoundation
import AudioToolbox

// MARK: - MeasurementLine

struct MeasurementLine {
    let id: UUID
    let entity: Entity
    let lineEntity: Entity
    let textEntity: Entity
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
        
        let containerEntity = Entity()
        let centerPosition = (leftPos + rightPos) / 2
        
        // Create line entity
        let lineEntity = Self.createLineEntity(
            from: leftPos,
            to: rightPos,
            at: centerPosition
        )
        
        // Create text entity
        let textEntity = Self.createTextEntity(
            distance: distance,
            at: centerPosition
        )
        
        containerEntity.addChild(lineEntity)
        containerEntity.addChild(textEntity)
        
        self.entity = containerEntity
        self.lineEntity = lineEntity
        self.textEntity = textEntity
    }
    
    // MARK: - Private Factory Methods
    
    private static func createLineEntity(
        from leftPos: SIMD3<Float>,
        to rightPos: SIMD3<Float>,
        at centerPosition: SIMD3<Float>
    ) -> Entity {
        let distance = simd.distance(leftPos, rightPos)
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
        
        return lineEntity
    }
    
    private static func createTextEntity(
        distance: Float,
        at centerPosition: SIMD3<Float>
    ) -> Entity {
        let textEntity = Entity()
        textEntity.position = centerPosition + SIMD3<Float>(0, 0.05, 0)
        
        let formattedDistance = formatDistance(distance)
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
        
        textEntity.components.set(BillboardComponent())
        
        return textEntity
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
>>>>>>> Stashed changes

// MARK: - AngleMeasurement

struct AngleMeasurement {
    let id: UUID
    let entity: Entity
    let pivotPosition: SIMD3<Float>
    let firstRayPosition: SIMD3<Float>
    let secondRayPosition: SIMD3<Float>
    let angleInDegrees: Float
    let timestamp: Date
    
    init(pivot: SIMD3<Float>, firstRay: SIMD3<Float>, secondRay: SIMD3<Float>) {
        self.id = UUID()
        self.pivotPosition = pivot
        self.firstRayPosition = firstRay
        self.secondRayPosition = secondRay
        self.timestamp = Date()
        
        // Calculate angle
        let vector1 = normalize(firstRay - pivot)
        let vector2 = normalize(secondRay - pivot)
        let dotProduct = dot(vector1, vector2)
        let angleRadians = acos(max(-1.0, min(1.0, dotProduct)))
        self.angleInDegrees = angleRadians * 180.0 / .pi
        
        // Create container
        let containerEntity = Entity()
        
        // Create first ray line
        let ray1Entity = Self.createRayLine(from: pivot, to: firstRay, color: .systemPurple)
        
        // Create second ray line
        let ray2Entity = Self.createRayLine(from: pivot, to: secondRay, color: .systemPurple)
        
        // Create pivot point sphere
        let pivotEntity = Entity()
        pivotEntity.position = pivot
        pivotEntity.components.set(ModelComponent(
            mesh: .generateSphere(radius: 0.008),
            materials: [SimpleMaterial(color: .systemOrange, roughness: 0.2, isMetallic: false)]
        ))
        
        // Create arc to visualize angle
        let arcEntity = Self.createAngleArc(
            pivot: pivot,
            firstRay: firstRay,
            secondRay: secondRay,
            angleRadians: angleRadians
        )
        
        // Create text label
        let textEntity = Entity()
        let labelPosition = pivot + SIMD3<Float>(0, 0.05, 0)
        textEntity.position = labelPosition
        
        let angleText = String(format: "%.1f°", angleInDegrees)
        let textMesh = MeshResource.generateText(
            angleText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.025, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        textEntity.components.set(ModelComponent(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .systemYellow, roughness: 0.1, isMetallic: false)]
        ))
        textEntity.components.set(BillboardComponent())
        
        // Assemble
        containerEntity.addChild(ray1Entity)
        containerEntity.addChild(ray2Entity)
        containerEntity.addChild(pivotEntity)
        containerEntity.addChild(arcEntity)
        containerEntity.addChild(textEntity)
        
        self.entity = containerEntity
    }
    
    private static func createRayLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor) -> Entity {
        let lineEntity = Entity()
        let distance = simd.distance(start, end)
        let center = (start + end) / 2
        
        lineEntity.position = center
        lineEntity.components.set(ModelComponent(
            mesh: .generateBox(
                width: 0.004,
                height: 0.004,
                depth: distance,
                cornerRadius: 0.001
            ),
            materials: [SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)]
        ))
        
        lineEntity.look(at: start, from: center, relativeTo: nil)
        lineEntity.components.set(OpacityComponent(opacity: 0.9))
        
        return lineEntity
    }
    
    private static func createAngleArc(
        pivot: SIMD3<Float>,
        firstRay: SIMD3<Float>,
        secondRay: SIMD3<Float>,
        angleRadians: Float
    ) -> Entity {
        let arcEntity = Entity()
        
        // Create a simple arc visualization using multiple small spheres
        let arcRadius: Float = 0.03
        let numSegments = max(3, Int(angleRadians * 10))
        
        let vector1 = normalize(firstRay - pivot)
        let vector2 = normalize(secondRay - pivot)
        
        for i in 0...numSegments {
            let t = Float(i) / Float(numSegments)
            let angle = angleRadians * t
            
            // Create rotation axis
            let rotationAxis = normalize(cross(vector1, vector2))
            
            // Rotate vector1 around the axis
            let rotation = simd_quatf(angle: angle, axis: rotationAxis)
            let direction = rotation.act(vector1)
            
            let pointPosition = pivot + direction * arcRadius
            
            let sphere = Entity()
            sphere.position = pointPosition
            sphere.components.set(ModelComponent(
                mesh: .generateSphere(radius: 0.003),
                materials: [SimpleMaterial(color: .systemYellow, roughness: 0.3, isMetallic: false)]
            ))
            
            arcEntity.addChild(sphere)
        }
        
        return arcEntity
    }
}

// MARK: - MyEntities

@MainActor
class MyEntities {
    
    // MARK: - Properties
    
    let root = Entity()
<<<<<<< Updated upstream
    let fingerTips: [HandAnchor.Chirality: Entity]
    let line = Entity()
    var resultBoard: Entity?
    
    init() {
        // Create more visible finger tip indicators
        let leftTip = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [SimpleMaterial(color: .red, roughness: 0.3, isMetallic: false)]
        )
        let rightTip = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: false)]
        )
=======
    var fingerTips: [HandAnchor.Chirality: Entity]
    let currentLine = Entity()
    var resultBoard: Entity?
    
    private var placedMeasurements: [MeasurementLine] = []
    private var annotations: [UUID: Entity] = [:]
    private var placedAngles: [AngleMeasurement] = []
    
    private var angleFirstRayStart: SIMD3<Float>?  // Pivot point (left hand)
    private var angleFirstRayEnd: SIMD3<Float>?    // First ray endpoint (right hand)
    private var angleReferenceEntity: Entity?
    private var tempAngleEntities: [Entity] = []
    
    // Angle measurement properties ƒ
    private var angleReferenceLineStart: SIMD3<Float>?
    private var angleReferenceLineEnd: SIMD3<Float>?
    
    
    var angleCount: Int {
        return placedAngles.count
    }
    
    var maxStoredMeasurements: Int = 20
    
    // MARK: - Constants
    
    private static let offscreenPosition = SIMD3<Float>(-1000, -1000, -1000)
    private static let minMeasurementDistance: Float = 0.005
    private static let trackingThreshold: Float = -999
    
    // MARK: - Initialization
    
    init() {
        let leftTip = Self.createArrowIndicator(color: .systemPurple)
        let rightTip = Self.createArrowIndicator(color: .systemPurple)
>>>>>>> Stashed changes
        
        leftTip.position = Self.offscreenPosition
        rightTip.position = Self.offscreenPosition
        
        fingerTips = [
            .left: leftTip,
            .right: rightTip
        ]
        
        fingerTips.values.forEach { root.addChild($0) }
        
<<<<<<< Updated upstream
        // Make the line more visible but initially hidden
        line.components.set(OpacityComponent(opacity: 0.9))
        line.isEnabled = false
        root.addChild(line)
=======
        currentLine.components.set(OpacityComponent(opacity: 0.9))
        currentLine.isEnabled = false
        root.addChild(currentLine)
>>>>>>> Stashed changes
        
        root.isEnabled = false
    }
    
    // MARK: - Public Methods
    
    func add(_ resultBoardEntity: Entity) {
        resultBoard = resultBoardEntity
        root.addChild(resultBoardEntity)
    }
    
<<<<<<< Updated upstream
    func update() {
=======
    func update(for mode: GestureMode = .measure) {
>>>>>>> Stashed changes
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else { return }
        
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
<<<<<<< Updated upstream
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        // Only show measurement when both hands are tracked
        guard isLeftTracked && isRightTracked else {
            line.isEnabled = false
            resultBoard?.isEnabled = false
            return
        }
        
        let centerPosition = (leftPos + rightPos) / 2
        let length = distance(leftPos, rightPos)
        
        // Only show the line if there's a meaningful distance
        if length > 0.005 { // Increased threshold
            line.position = centerPosition
            line.components.set(ModelComponent(
                mesh: .generateBox(
                    width: 0.003,
                    height: 0.003,
                    depth: length,
                    cornerRadius: 0.001
                ),
                materials: [SimpleMaterial(color: .yellow, roughness: 0.2, isMetallic: false)]
            ))
            
            line.look(at: leftPos, from: centerPosition, relativeTo: nil)
            line.isEnabled = true
            resultBoard?.isEnabled = true
        } else {
            line.isEnabled = false
            resultBoard?.isEnabled = false
        }
        
        // Position the result board above the center point
        resultBoard?.setPosition(centerPosition + SIMD3<Float>(0, 0.1, 0), relativeTo: nil)
    }
    
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
        
=======
        guard isTracked(leftPos), isTracked(rightPos) else {
            hideCurrentLineAndBoard()
            return
        }
        
        switch mode {
        case .measure, .angle:
            updateMeasurementLine(leftPos: leftPos, rightPos: rightPos, mode: mode)
        case .annotate, .none, .drag, .rotate, .scale, .crop:
            hideCurrentLineAndBoard()
        }
        
        updateArrowOrientations()
    }
    
    // MARK: - Angle Measurement Methods (NEW WORKFLOW)
    
    var hasActiveAngleReference: Bool {
        return angleFirstRayStart != nil && angleFirstRayEnd != nil
    }

    func placeAngleReferenceLine(leftPos: SIMD3<Float>, rightPos: SIMD3<Float>) {
        // Clear any existing reference line
        clearAngleReference()
        
        // Store the STATIC reference line positions
        // This line will NOT move with the hands anymore
        angleFirstRayStart = leftPos
        angleFirstRayEnd = rightPos
        
        // Create visual representation of the FIRST RAY (reference line)
        let referenceEntity = Entity()
        let distance = simd.distance(leftPos, rightPos)
        let center = (leftPos + rightPos) / 2
        
        referenceEntity.position = center
        referenceEntity.components.set(ModelComponent(
            mesh: .generateBox(
                width: 0.005,
                height: 0.005,
                depth: distance,
                cornerRadius: 0.001
            ),
            materials: [SimpleMaterial(color: .systemBlue, roughness: 0.2, isMetallic: false)]
        ))
        
        referenceEntity.look(at: leftPos, from: center, relativeTo: nil)
        referenceEntity.components.set(OpacityComponent(opacity: 0.9))
        
        // Add markers at endpoints to show this is the PIVOT and FIRST RAY ENDPOINT
        let pivotMarker = Entity()
        pivotMarker.position = leftPos  // This is the PIVOT (left hand position)
        pivotMarker.components.set(ModelComponent(
            mesh: .generateSphere(radius: 0.012),
            materials: [SimpleMaterial(color: .systemRed, roughness: 0.2, isMetallic: false)]
        ))
        
        let endMarker = Entity()
        endMarker.position = rightPos  // This is the end of first ray
        endMarker.components.set(ModelComponent(
            mesh: .generateSphere(radius: 0.008),
            materials: [SimpleMaterial(color: .systemBlue, roughness: 0.2, isMetallic: false)]
        ))
        
        let container = Entity()
        container.addChild(referenceEntity)
        container.addChild(pivotMarker)
        container.addChild(endMarker)
        
        root.addChild(container)
        angleReferenceEntity = container
        tempAngleEntities.append(container)
        
        playSystemClick(1)
        print("🔵 First ray placed - Left hand (PIVOT): \(leftPos), Right hand (ray end): \(rightPos)")
        print("   Now right pinch to place second ray and complete angle measurement")
    }

    func completeAngleWithRightHand(rightPos: SIMD3<Float>) {
        guard let pivot = angleFirstRayStart,  // Left hand position = PIVOT
              let firstRayEnd = angleFirstRayEnd else {  // Right hand position when first ray was placed
            print("⚠️ No reference line set")
            return
        }
        
        // Now we create angle measurement:
        // - Pivot point: where left hand was during left pinch
        // - First ray: from pivot to where right hand was during left pinch
        // - Second ray: from pivot to where right hand is NOW (during right pinch)
        
        print("📐 Creating angle:")
        print("   Pivot: \(pivot)")
        print("   First ray end: \(firstRayEnd)")
        print("   Second ray end (current right hand): \(rightPos)")
        
        let angle = AngleMeasurement(
            pivot: pivot,
            firstRay: firstRayEnd,
            secondRay: rightPos
        )
        
        root.addChild(angle.entity)
        placedAngles.append(angle)
        
        // Clear the reference line and temporary entities
        clearAngleReference()
        
        // Limit stored angles
        if placedAngles.count > maxStoredMeasurements {
            let oldest = placedAngles.removeFirst()
            oldest.entity.removeFromParent()
        }
        
        playSystemClick(1)
        print("✅ Angle measurement complete: \(String(format: "%.1f°", angle.angleInDegrees))")
    }

    func clearAngleReference() {
        angleFirstRayStart = nil
        angleFirstRayEnd = nil
        angleReferenceEntity?.removeFromParent()
        angleReferenceEntity = nil
        clearTempAngleEntities()
    }

    private func clearTempAngleEntities() {
        tempAngleEntities.forEach { $0.removeFromParent() }
        tempAngleEntities.removeAll()
    }

    func removeLastAngle() {
        // If there's an active reference, cancel it
        if hasActiveAngleReference {
            clearAngleReference()
            playSystemClick(2)
            print("❌ Cancelled angle reference line")
            return
        }
        
        // Otherwise remove the last completed angle
        guard let lastAngle = placedAngles.popLast() else {
            print("No angles to remove")
            return
        }
        lastAngle.entity.removeFromParent()
        playSystemClick(2)
        print("🗑️ Last angle removed")
    }

    func clearAllAngles() {
        clearAngleReference()
        placedAngles.forEach { $0.entity.removeFromParent() }
        placedAngles.removeAll()
        print("🧹 All angles cleared")
    }

    func getAllAngles() -> [AngleMeasurement] {
        return placedAngles
    }

    func getAngleResultString() -> String {
        if hasActiveAngleReference {
            return "Right pinch to place second ray ➡️"
        }
        
        let count = placedAngles.count
        if count == 0 {
            return "Left pinch: both hands define first ray (pivot + direction)"
        } else if count == 1 {
            return "1 angle measured"
        } else {
            return "\(count) angles measured"
        }
    }

    private func setAngleVisibility(_ isVisible: Bool) {
        placedAngles.forEach { $0.entity.isEnabled = isVisible }
        tempAngleEntities.forEach { $0.isEnabled = isVisible }
    }

    
    // MARK: - Measurement Management
    
    func placeMeasurement() {
        guard let leftPos = fingerTips[.left]?.position,
              let rightPos = fingerTips[.right]?.position else {
            print("Cannot place measurement: fingertip entities not found")
            return
        }
        
        guard isTracked(leftPos), isTracked(rightPos) else {
            print("Cannot place measurement: hands not tracked")
            return
        }
        
        let length = distance(leftPos, rightPos)
        guard length > Self.minMeasurementDistance else {
            print("Cannot place measurement: distance too small (\(length)m)")
            return
        }
        
        let measurement = MeasurementLine(leftPos: leftPos, rightPos: rightPos)
        root.addChild(measurement.entity)
        placedMeasurements.append(measurement)
        
        // Remove oldest if exceeding limit
        if placedMeasurements.count > maxStoredMeasurements {
            let oldest = placedMeasurements.removeFirst()
            oldest.entity.removeFromParent()
        }
        
        playSystemClick(1)
    }
    
    func removeLastMeasurement() {
        guard let lastMeasurement = placedMeasurements.popLast() else {
            print("No measurements to remove")
            return
        }
        lastMeasurement.entity.removeFromParent()
        playSystemClick(2)
    }
    
    func clearAllMeasurements() {
        placedMeasurements.forEach { $0.entity.removeFromParent() }
        placedMeasurements.removeAll()
        print("Cleared all measurements")
    }
    
    func getAllMeasurements() -> [MeasurementLine] {
        return placedMeasurements
    }
    
    var measurementCount: Int {
        return placedMeasurements.count
    }
    
    func getMeasurementStats() -> (count: Int, average: Float, min: Float, max: Float)? {
        guard !placedMeasurements.isEmpty else { return nil }
        
        let distances = placedMeasurements.map { $0.distance }
        let sum = distances.reduce(0, +)
        let average = sum / Float(distances.count)
        let min = distances.min() ?? 0
        let max = distances.max() ?? 0
        
        return (count: distances.count, average: average, min: min, max: max)
    }
    
    // MARK: - Annotation Management
    
    func addAnnotation(_ annotation: AnnotationNote) {
        root.addChild(annotation.entity)
        annotations[annotation.id] = annotation.entity
        print("Added annotation to scene: \(annotation.id)")
    }
    
    func removeAnnotation(id: UUID) {
        guard let entity = annotations[id] else {
            print("Annotation not found: \(id)")
            return
        }
        entity.removeFromParent()
        annotations.removeValue(forKey: id)
        print("Removed annotation from scene: \(id)")
    }
    
    func clearAllAnnotations() {
        annotations.values.forEach { $0.removeFromParent() }
        annotations.removeAll()
        print("Cleared all annotations from scene")
    }
    
    var sceneAnnotationCount: Int {
        return annotations.count
    }
    
    // MARK: - Mode-Based Visibility
    
    func updateVisibilityForMode(_ mode: GestureMode) {
        switch mode {
        case .measure:
            setMeasurementVisibility(true)
            setAngleVisibility(false)
            setFingerTipVisibility(true)
            
        case .angle:
            setMeasurementVisibility(false)
            setAngleVisibility(true)
            setFingerTipVisibility(true)
            
        case .annotate:
            setMeasurementVisibility(false)
            setAngleVisibility(false)
            setFingerTipVisibility(true)
            
        case .none, .drag, .rotate, .scale, .crop:
            setMeasurementVisibility(false)
            setAngleVisibility(false)
            setFingerTipVisibility(false)
        }
    }
    
    // MARK: - Display and Formatting
    
    func getResultString() -> String {
        guard let leftPos = fingerTips[.left]?.position,
              let rightPos = fingerTips[.right]?.position else {
            return "No entities"
        }
        
        guard isTracked(leftPos), isTracked(rightPos) else {
            return "Show both hands to camera"
        }
        
        let length = distance(leftPos, rightPos)
        
        guard length >= Self.minMeasurementDistance else {
            return "Touch index fingers"
        }
        
        let currentMeasurement = formatDistance(length)
        let storedCount = placedMeasurements.count
        
        return storedCount > 0 ? "\(currentMeasurement)\n(\(storedCount) stored)" : currentMeasurement
    }
    
    // MARK: - Audio
    
    func playSystemClick(_ num: Int = 1) {
        let soundID: SystemSoundID = num == 1 ? 1104 : 1155
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK: - Private Helper Methods
    
    private func isTracked(_ position: SIMD3<Float>) -> Bool {
        return position.x > Self.trackingThreshold &&
               position.y > Self.trackingThreshold &&
               position.z > Self.trackingThreshold
    }
    
    private func hideCurrentLineAndBoard() {
        currentLine.isEnabled = false
        resultBoard?.isEnabled = false
    }
    
    private func updateMeasurementLine(leftPos: SIMD3<Float>, rightPos: SIMD3<Float>, mode: GestureMode) {
        let centerPosition = (leftPos + rightPos) / 2
        let length = distance(leftPos, rightPos)
        
        guard length > Self.minMeasurementDistance else {
            hideCurrentLineAndBoard()
            return
        }
        
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
        
        resultBoard?.setPosition(centerPosition + SIMD3<Float>(0, 0.01, 0), relativeTo: nil)
        resultBoard?.isEnabled = true
    }
    
    private func setMeasurementVisibility(_ isVisible: Bool) {
        placedMeasurements.forEach { $0.entity.isEnabled = isVisible }
        currentLine.isEnabled = isVisible
    }
    
    private func setFingerTipVisibility(_ isVisible: Bool) {
        fingerTips.values.forEach { $0.isEnabled = isVisible }
    }
    
    private func formatDistance(_ length: Float) -> String {
>>>>>>> Stashed changes
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.minimumFractionDigits = 2
        formatter.numberFormatter.maximumFractionDigits = 2
        
<<<<<<< Updated upstream
        let length = distance(leftPos, rightPos)
        
        if length < 0.005 {
            return " index fingers"
        }
        
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
=======
        if length < 0.01 {
            return formatter.string(from: .init(value: Double(length * 1000), unit: UnitLength.millimeters))
        } else if length < 1.0 {
            return formatter.string(from: .init(value: Double(length * 100), unit: UnitLength.centimeters))
        } else {
            return formatter.string(from: .init(value: Double(length), unit: UnitLength.meters))
        }
    }
    
    // MARK: - Arrow Indicator Methods
    
    private static func createArrowIndicator(color: UIColor) -> Entity {
        let arrowEntity = Entity()
        let arrow = ModelEntity(
            mesh: .generateCone(height: 0.015, radius: 0.006),
            materials: [SimpleMaterial(color: color, roughness: 0.1, isMetallic: false)]
        )
        
        arrow.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        arrowEntity.addChild(arrow)
        
        return arrowEntity
    }
    
    private func updateArrowOrientations() {
        guard let leftPos = fingerTips[.left]?.position,
              let rightPos = fingerTips[.right]?.position else { return }
        
        guard isTracked(leftPos), isTracked(rightPos) else { return }
        
        let lineDirection = normalize(rightPos - leftPos)
        
        fingerTips[.left]?.orientation = orientationFromDirection(-lineDirection)
        fingerTips[.right]?.orientation = orientationFromDirection(lineDirection)
    }
    
    private func orientationFromDirection(_ direction: SIMD3<Float>) -> simd_quatf {
        let defaultDirection = SIMD3<Float>(0, 0, 1)
        let normalizedDirection = normalize(direction)
        
        // Handle opposite directions
        if dot(defaultDirection, normalizedDirection) < -0.999 {
            return simd_quatf(angle: .pi, axis: [0, 1, 0])
        }
        
        let rotationAxis = normalize(cross(defaultDirection, normalizedDirection))
        let cosAngle = dot(defaultDirection, normalizedDirection)
        let angle = acos(max(-1.0, min(1.0, cosAngle)))
        
        if length(rotationAxis) > 0.001 {
            return simd_quatf(angle: angle, axis: rotationAxis)
        } else {
            return simd_quatf(angle: 0, axis: [0, 1, 0])
        }
    }
>>>>>>> Stashed changes
}
