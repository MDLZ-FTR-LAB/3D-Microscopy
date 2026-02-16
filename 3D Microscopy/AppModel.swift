//
//  AppModel.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//

import SwiftUI
import RealityKit
import ARKit
import Combine


enum GestureMode: String, CaseIterable {
    case none, drag, rotate, scale, measure, annotate, crop, angle
}

@MainActor
class AppModel: ObservableObject {

    @Published var gestureMode: GestureMode = .none

    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    @Published var immersiveSpaceState = ImmersiveSpaceState.closed
    @Published var modelURL: URL? = nil
    @Published var availableModels: [URL] = []
    
    
    // Crop-specific properties
    @Published var cropPreviewEntity: ModelEntity?
    @Published var isDrawingCropLine = false
    @Published var cropStartPoint: SIMD3<Float>?
    @Published var cropEndPoint: SIMD3<Float>?
    var cancellables: Set<AnyCancellable> = []


    func cleanupCropPreview() {
        cropPreviewEntity?.removeFromParent()
        cropPreviewEntity = nil
    }
    
    
    
    //for on/off button
    @Published var isOn: Bool = false {
        didSet {
            myEntities.root.isEnabled = isOn
        }
    }

    //hand tracking code
    private var arKitSession = ARKitSession()
    private var handTrackingProvider = HandTrackingProvider()
    @Published var resultString: String = ""
    let myEntities = MyEntities()
    
    // MARK: - Annotation System
    @Published var annotationManager = AnnotationManager()
    @Published var pendingAnnotationPosition: SIMD3<Float>?
    
    // MARK: - Pinch Detection Properties
    private var leftPinchDistance: Float = 0
    private var rightPinchDistance: Float = 0
    private var leftWasPinched: Bool = false
    private var rightWasPinched: Bool = false
    private let pinchThreshold: Float = 0.025 // 2.5cm threshold for pinch detection
    private var lastPinchTime: Date = Date()
    private let pinchCooldown: TimeInterval = 0.5 // Half second cooldown between pinches
    
    // MARK: - Session Management
    
    func runSession() async {
        do {
            if HandTrackingProvider.isSupported {
                print("Hand tracking is supported")
                try await arKitSession.run([handTrackingProvider])
                print("Hand tracking session started successfully")
            } else {
                print("Hand tracking is not supported on this device")
            }
        } catch {
            print("Failed to start hand tracking: \(error)")
        }
    }
    
    func processAnchorUpdates() async {
        print("Starting to process anchor updates...")
        
        for await update in handTrackingProvider.anchorUpdates {
            let handAnchor = update.anchor
            let handType = handAnchor.chirality == .left ? "LEFT" : "RIGHT"
            
            if !handAnchor.isTracked {
                continue
            }
            
//            let indexJoint = handSkeleton.joint(.indexFingerTip)
//            guard indexJoint.isTracked else { continue }
//            
//            // Update fingertip position
//            let originFromIndex = calculateOriginTransform(handAnchor: handAnchor, joint: indexJoint)
//            updateFingerTipEntity(chirality: handAnchor.chirality, transform: originFromIndex)
//            
//            // Handle pinch detection for measure, annotate, and angle modes
//            if (gestureMode == .measure || gestureMode == .annotate || gestureMode == .angle) && isOn {
//                handlePinchDetection(handAnchor: handAnchor,
//                                   handSkeleton: handSkeleton,
//                                   indexTransform: originFromIndex)
            guard let handSkeleton = handAnchor.handSkeleton else {
                continue
            }
            
            // Get both index finger tip and thumb tip for pinch detection
            let indexJoint = handSkeleton.joint(.indexFingerTip)
            let thumbJoint = handSkeleton.joint(.thumbTip)
            
            guard indexJoint.isTracked else {
                continue
            }
            
            let originFromWrist = handAnchor.originFromAnchorTransform
            let wristFromIndex = indexJoint.anchorFromJointTransform
            let originFromIndex = originFromWrist * wristFromIndex
            
            // Update fingertip entity position (existing functionality)
            let fingerTipEntity = myEntities.fingerTips[handAnchor.chirality]
            fingerTipEntity?.setTransformMatrix(originFromIndex, relativeTo: nil)
            
            // MARK: - Pinch Detection for Measure and Annotate modes
            if thumbJoint.isTracked && (gestureMode == .measure || gestureMode == .annotate) && isOn {
                let wristFromThumb = thumbJoint.anchorFromJointTransform
                let originFromThumb = originFromWrist * wristFromThumb
                
                // Calculate positions
                let indexPos = SIMD3<Float>(originFromIndex.columns.3.x,
                                          originFromIndex.columns.3.y,
                                          originFromIndex.columns.3.z)
                let thumbPos = SIMD3<Float>(originFromThumb.columns.3.x,
                                          originFromThumb.columns.3.y,
                                          originFromThumb.columns.3.z)
                
                let pinchDistance = distance(indexPos, thumbPos)
                
                // Detect pinch gestures
                detectPinchGesture(handAnchor.chirality, pinchDistance, indexPos)
            }
            
            // Only update visual elements if measuring is on (existing functionality)
            if isOn {
                myEntities.update()
                
                // Update result string based on current mode
                switch gestureMode {
                case .measure:
                    resultString = myEntities.getResultString()
                case .annotate:
                    resultString = annotationManager.getAnnotationSummary()
                default:
                    resultString = ""
                }
            }
        }
    }
    
//    private func updateUIElements() {
//        guard isOn else { return }
//        
//        myEntities.update(for: gestureMode)
//        
//        switch gestureMode {
//        case .measure:
//            resultString = myEntities.getResultString()
//        case .angle:
//            resultString = myEntities.getAngleResultString()
//        case .annotate:
//            resultString = annotationManager.getAnnotationSummary()
//        default:
//            resultString = ""
//        }
//    }
//    
//    private func calculateOriginTransform(handAnchor: HandAnchor, joint: HandSkeleton.Joint) -> simd_float4x4 {
//        let originFromWrist = handAnchor.originFromAnchorTransform
//        let wristFromJoint = joint.anchorFromJointTransform
//        return originFromWrist * wristFromJoint
//    }
//    
//    private func updateFingerTipEntity(chirality: HandAnchor.Chirality, transform: simd_float4x4) {
//        myEntities.fingerTips[chirality]?.setTransformMatrix(transform, relativeTo: nil)
//    }
//    
//    private func handlePinchDetection(handAnchor: HandAnchor,
//                                     handSkeleton: HandSkeleton,
//                                     indexTransform: simd_float4x4) {
//        let thumbJoint = handSkeleton.joint(.thumbTip)
//        guard thumbJoint.isTracked else { return }
//        
//        let thumbTransform = calculateOriginTransform(handAnchor: handAnchor, joint: thumbJoint)
//        
//        let indexPos = extractPosition(from: indexTransform)
//        let thumbPos = extractPosition(from: thumbTransform)
//        let pinchDistance = distance(indexPos, thumbPos)
//        
//        detectPinchGesture(handAnchor.chirality, pinchDistance, indexPos)
//    }
//    
//    private func extractPosition(from transform: simd_float4x4) -> SIMD3<Float> {
//        return SIMD3<Float>(transform.columns.3.x,
//                           transform.columns.3.y,
//                           transform.columns.3.z)
//    }
//    
//    // MARK: - Pinch Gesture Detection
//    
//    private func detectPinchGesture(_ chirality: HandAnchor.Chirality,
//                                   _ currentDistance: Float,
//                                   _ indexPosition: SIMD3<Float>) {
    // MARK: - Pinch Detection Methods
    private func detectPinchGesture(_ chirality: HandAnchor.Chirality, _ currentDistance: Float, _ indexPosition: SIMD3<Float>) {
        let now = Date()
        
        // Check cooldown to prevent rapid-fire pinches
        guard now.timeIntervalSince(lastPinchTime) > pinchCooldown else { return }
        
        switch chirality {
        case .left:
            let wasPinched = leftWasPinched
            let isPinched = currentDistance < pinchThreshold
            
            if !wasPinched && isPinched {
                if gestureMode == .measure {
                    // Left hand just pinched - place measurement
                    handleLeftPinch()
                } else if gestureMode == .annotate {
                    // Left hand just pinched - create annotation
                    handleAnnotationPinch(at: indexPosition)
                }
                lastPinchTime = now
            }
            leftWasPinched = isPinched
            leftPinchDistance = currentDistance
            
        case .right:
            let wasPinched = rightWasPinched
            let isPinched = currentDistance < pinchThreshold
            
            if !wasPinched && isPinched {
                if gestureMode == .measure {
                    // Right hand just pinched - remove last measurement
                    handleRightPinch()
                } else if gestureMode == .annotate {
                    // Right hand just pinched - remove last annotation
                    handleAnnotationRemove()
                }
                lastPinchTime = now
            }
            rightWasPinched = isPinched
            rightPinchDistance = currentDistance
        }
    }
    
//    private func handleLeftHandPinch(currentDistance: Float,
//                                    indexPosition: SIMD3<Float>,
//                                    now: Date) {
//        let isPinched = currentDistance < pinchThreshold
//        
//        if !leftWasPinched && isPinched {
//            switch gestureMode {
//            case .measure:
//                handleLeftPinch()
//            case .annotate:
//                handleAnnotationPinch(at: indexPosition)
//            case .angle:
//                handleAngleLeftPinch(at: indexPosition)
//            default:
//                break
//            }
//            lastPinchTime = now
//        }
//        
//        leftWasPinched = isPinched
//        leftPinchDistance = currentDistance
//    }
//    
//    private func handleRightHandPinch(currentDistance: Float, now: Date) {
//        let isPinched = currentDistance < pinchThreshold
//        
//        if !rightWasPinched && isPinched {
//            switch gestureMode {
//            case .measure:
//                handleRightPinch()
//            case .annotate:
//                handleAnnotationRemove()
//            case .angle:
//                handleAngleRightPinch()
//            default:
//                break
//            }
//            lastPinchTime = now
//        }
//        
//        rightWasPinched = isPinched
//        rightPinchDistance = currentDistance
//    }
//    
//    // MARK: - Measurement Mode Handlers
//    
//    private func handleLeftPinch() {
//        myEntities.placeMeasurement()
//        print("📏 Measurement placed via left hand pinch")
//    }
//    
//    private func handleRightPinch() {
//        myEntities.removeLastMeasurement()
//        print("🗑️ Last measurement removed via right hand pinch")
//    }
//    
//    // MARK: - Annotation Mode Handlers
//    
//    private func handleAnnotationPinch(at position: SIMD3<Float>) {
//        pendingAnnotationPosition = position
//        print("📌 Annotation pinch detected at position: \(position)")
    private func handleLeftPinch() {
        // Left hand pinch = Place measurement
        myEntities.placeMeasurement()
        print("Measurement placed via left hand pinch")
    }
    
    private func handleRightPinch() {
        // Right hand pinch = Remove last measurement
        myEntities.removeLastMeasurement()
        print("Last measurement removed via right hand pinch")
    }
    
    // MARK: - Annotation Methods
    private func handleAnnotationPinch(at position: SIMD3<Float>) {
        // Store the position for annotation creation and trigger text input
        pendingAnnotationPosition = position
        print("Annotation pinch detected at position: \(position)")
    }
    
    private func handleAnnotationRemove() {
        annotationManager.removeLastAnnotation()
//        print("🗑️ Last annotation removed via right hand pinch")
//    }
        print("Last annotation removed via right hand pinch")
    }
    
    /// Create annotation at pending position with given text
    func createAnnotationWithText(_ text: String) {
        guard let position = pendingAnnotationPosition else {
            print("No pending annotation position")
            return
        }
        
        let annotation = annotationManager.createAnnotation(at: position, text: text)
//        myEntities.addAnnotation(annotation)
//        pendingAnnotationPosition = nil
//        
//        print("✅ Annotation created with text: '\(text)' at position: \(position)")
//    }
//    
//        
        // Add annotation entity to scene
        //myEntities.addAnnotation(annotation)
        
        // Clear pending position
        pendingAnnotationPosition = nil
        
        print("Annotation created with text: '\(text)' at position: \(position)")
    }
    
    /// Cancel pending annotation creation
    func cancelPendingAnnotation() {
        pendingAnnotationPosition = nil
    }
    
//    // MARK: - Angle Mode Handlers
//    
//    private func handleAngleLeftPinch(at position: SIMD3<Float>) {
//        // Left pinch: Place the reference line using current finger positions
//        guard let leftPos = myEntities.fingerTips[.left]?.position,
//              let rightPos = myEntities.fingerTips[.right]?.position else {
//            print("⚠️ Cannot get finger positions")
//            return
//        }
//        
//        guard isTracked(leftPos), isTracked(rightPos) else {
//            print("⚠️ Hands not tracked")
//            return
//        }
//        
//        // Place a reference line between both hands
//        myEntities.placeAngleReferenceLine(leftPos: leftPos, rightPos: rightPos)
//    }
//    
//    private func handleAngleRightPinch() {
//        // Right pinch: Complete the angle measurement or remove last
//        if myEntities.hasActiveAngleReference {
//            // If there's an active reference line, complete the measurement
//            guard let rightPos = myEntities.fingerTips[.right]?.position else {
//                return
//            }
//            
//            guard isTracked(rightPos) else {
//                return
//            }
//            
//            // Use right hand position to complete the angle
//            myEntities.completeAngleWithRightHand(rightPos: rightPos)
//        } else {
//            // If no active reference, remove the last completed angle
//            myEntities.removeLastAngle()
//        }
//    }
//    
    // MARK: - Public Measurement Methods
    
    // MARK: - Public Methods for UI Controls
    func placeMeasurement() {
        myEntities.placeMeasurement()
    }
    
    func removeLastMeasurement() {
        myEntities.removeLastMeasurement()
    }
    
    func clearAllMeasurements() {
        myEntities.clearAllMeasurements()
        print("🧹 All measurements cleared")
    }
    
//    // MARK: - Public Annotation Methods
//    
//    func placeAnnotation(at position: SIMD3<Float>, text: String = "") {
//        let annotation = annotationManager.createAnnotation(at: position, text: text)
//        myEntities.addAnnotation(annotation)
//        print("📌 Annotation placed at: \(position)")
//    }
//    
//    func removeLastAnnotation() {
//        guard let lastAnnotation = annotationManager.getAllAnnotations().last else { return }
//        annotationManager.removeAnnotation(id: lastAnnotation.id)
//        myEntities.removeAnnotation(id: lastAnnotation.id)
//    }
//    
//    func clearAllAnnotations() {
//        let allAnnotations = annotationManager.getAllAnnotations()
//        allAnnotations.forEach { annotation in
//            myEntities.removeAnnotation(id: annotation.id)
//        }
//        annotationManager.clearAllAnnotations()
//        print("🧹 All annotations cleared")
//    }
//    
//    // MARK: - Public Angle Methods
//    
//    func clearAllAngles() {
//        myEntities.clearAllAngles()
//        print("🧹 All angles cleared")
//    }
//    
//    // MARK: - Helper Methods
//    
//    private func isTracked(_ position: SIMD3<Float>) -> Bool {
//        let trackingThreshold: Float = -999
//        return position.x > trackingThreshold &&
//               position.y > trackingThreshold &&
//               position.z > trackingThreshold
//    }

    func placeAnnotation(at position: SIMD3<Float>, text: String = "") {
        let annotation = annotationManager.createAnnotation(at: position, text: text)
        //myEntities.addAnnotation(annotation)
        print("Annotation placed at: \(position)")
    }
    
    func removeLastAnnotation() {
        annotationManager.removeLastAnnotation()
    }
    
    func clearAllAnnotations() {
        annotationManager.clearAllAnnotations()
        //myEntities.clearAllAnnotations()
        print("🧹 All annotations cleared")
    }
    
    // MARK: - Debug Methods
    func getPinchStatus() -> String {
        let leftStatus = leftWasPinched ? "PINCHED" : String(format: "%.1fcm", leftPinchDistance * 100)
        let rightStatus = rightWasPinched ? "PINCHED" : String(format: "%.1fcm", rightPinchDistance * 100)
        return "L: \(leftStatus) | R: \(rightStatus)"
    }
}
