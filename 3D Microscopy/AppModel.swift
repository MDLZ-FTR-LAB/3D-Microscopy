//
//  AppModel.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//

import SwiftUI
import RealityKit
import ARKit

// MARK: - Enums

enum GestureMode: String, CaseIterable {
<<<<<<< Updated upstream
        case none, drag, rotate, scale, measure, crop
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
=======
    case none, drag, rotate, scale, measure, annotate, crop, angle
}

enum ImmersiveSpaceState {
    case closed, inTransition, open
}

// MARK: - AppModel

@MainActor
class AppModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var gestureMode: GestureMode = .none {
        didSet {
            myEntities.updateVisibilityForMode(gestureMode)
        }
    }
>>>>>>> Stashed changes
    
    @Published var immersiveSpaceState = ImmersiveSpaceState.closed
    @Published var modelURL: URL?
    @Published var availableModels: [URL] = []
    @Published var isOn: Bool = false {
        didSet {
            myEntities.root.isEnabled = isOn
        }
    }
<<<<<<< Updated upstream
    
    //hand tracking code
       private var arKitSession = ARKitSession()
       private var handTrackingProvider = HandTrackingProvider()
       @Published var resultString: String = ""
       let myEntities = MyEntities()
       
       func runSession() async {
           do {
               if HandTrackingProvider.isSupported {
                   print(" tracking is supported")
                   try await arKitSession.run([handTrackingProvider])
                   print("and tracking session started successfully")
               } else {
                   print("and tracking is not supported on this device")
               }
           } catch {
               print("Failed  \(error)")
           }
       }
       
       func processAnchorUpdates() async {
           print("Starting to process anchor updates...")
           
           for await update in handTrackingProvider.anchorUpdates {
               let handAnchor = update.anchor
               let handType = handAnchor.chirality == .left ? "LEFT" : "RIGHT"
               
               if !handAnchor.isTracked {
//                   print("\(handType) hand not tracked")
                   continue
               }
               
               guard let handSkeleton = handAnchor.handSkeleton else {
//                   print("\(handType) hand skeleton not available")
                   continue
               }
               
               let joint = handSkeleton.joint(.indexFingerTip);
               
               guard joint.isTracked else {
//                   print("\(handType) index finger tip not tracked")
                   continue
               }
               
               let originFromWrist = handAnchor.originFromAnchorTransform
               let wristFromIndex = joint.anchorFromJointTransform
               let originFromIndex = originFromWrist * wristFromIndex
               
               let fingerTipEntity = myEntities.fingerTips[handAnchor.chirality]
               fingerTipEntity?.setTransformMatrix(originFromIndex, relativeTo: nil)
               
               // debug position
//               let position = fingerTipEntity?.position ?? SIMD3<Float>(0, 0, 0)
//               if isOn && (handAnchor.chirality == .left) { // Only log left hand to reduce spam
////                   print("\(handType) finger at: \(position)")
//               }
               
               // Only update visual elements if measuring is on
               if isOn {
                   myEntities.update()
                   resultString = myEntities.getResultString()
               }
           }
       }
   }
=======
    @Published var resultString: String = ""
    @Published var annotationManager = AnnotationManager()
    @Published var pendingAnnotationPosition: SIMD3<Float>?
    
    // MARK: - Constants
    
    let immersiveSpaceID = "ImmersiveSpace"
    let myEntities = MyEntities()
    
    // MARK: - Private Properties
    
    private var arKitSession = ARKitSession()
    private var handTrackingProvider = HandTrackingProvider()
    
    // Pinch detection
    private var leftPinchDistance: Float = 0
    private var rightPinchDistance: Float = 0
    private var leftWasPinched: Bool = false
    private var rightWasPinched: Bool = false
    private let pinchThreshold: Float = 0.025 // 2.5cm
    private var lastPinchTime: Date = Date()
    private let pinchCooldown: TimeInterval = 0.5
    
    // Angle measurement (unused)
    private var anglePivotPosition: SIMD3<Float>?
    private var angleFirstRayPosition: SIMD3<Float>?
    private var leftPinchActive: Bool = false
    private var rightPinchActive: Bool = false
    
    // MARK: - Session Management
    
    func runSession() async {
        do {
            guard HandTrackingProvider.isSupported else {
                print("Hand tracking is not supported on this device")
                return
            }
            
            print("Hand tracking is supported")
            try await arKitSession.run([handTrackingProvider])
            print("Hand tracking session started successfully")
        } catch {
            print("Failed to start hand tracking: \(error)")
        }
    }
    
    // MARK: - Hand Tracking
    
    func processAnchorUpdates() async {
        print("Starting to process anchor updates...")
        
        for await update in handTrackingProvider.anchorUpdates {
            let handAnchor = update.anchor
            
            guard handAnchor.isTracked, let handSkeleton = handAnchor.handSkeleton else {
                continue
            }
            
            let indexJoint = handSkeleton.joint(.indexFingerTip)
            guard indexJoint.isTracked else { continue }
            
            // Update fingertip position
            let originFromIndex = calculateOriginTransform(handAnchor: handAnchor, joint: indexJoint)
            updateFingerTipEntity(chirality: handAnchor.chirality, transform: originFromIndex)
            
            // Handle pinch detection for measure and annotate modes
            if (gestureMode == .measure || gestureMode == .annotate || gestureMode == .angle) && isOn {
                handlePinchDetection(handAnchor: handAnchor,
                                   handSkeleton: handSkeleton,
                                   indexTransform: originFromIndex)
            }
            
            // Update visual elements and result string
            updateUIElements()
        }
    }
    
    private func updateUIElements() {
        guard isOn else { return }
        
        myEntities.update(for: gestureMode)
        
        switch gestureMode {
        case .measure:
            resultString = myEntities.getResultString()
        case .angle:
            resultString = myEntities.getAngleResultString()
        case .annotate:
            resultString = annotationManager.getAnnotationSummary()
        default:
            resultString = ""
        }
    }
    
    private func calculateOriginTransform(handAnchor: HandAnchor, joint: HandSkeleton.Joint) -> simd_float4x4 {
        let originFromWrist = handAnchor.originFromAnchorTransform
        let wristFromJoint = joint.anchorFromJointTransform
        return originFromWrist * wristFromJoint
    }
    
    private func updateFingerTipEntity(chirality: HandAnchor.Chirality, transform: simd_float4x4) {
        myEntities.fingerTips[chirality]?.setTransformMatrix(transform, relativeTo: nil)
    }
    
    private func handlePinchDetection(handAnchor: HandAnchor,
                                     handSkeleton: HandSkeleton,
                                     indexTransform: simd_float4x4) {
        let thumbJoint = handSkeleton.joint(.thumbTip)
        guard thumbJoint.isTracked else { return }
        
        let thumbTransform = calculateOriginTransform(handAnchor: handAnchor, joint: thumbJoint)
        
        let indexPos = extractPosition(from: indexTransform)
        let thumbPos = extractPosition(from: thumbTransform)
        let pinchDistance = distance(indexPos, thumbPos)
        
        detectPinchGesture(handAnchor.chirality, pinchDistance, indexPos)
    }
    
    private func extractPosition(from transform: simd_float4x4) -> SIMD3<Float> {
        return SIMD3<Float>(transform.columns.3.x,
                           transform.columns.3.y,
                           transform.columns.3.z)
    }

    
    // MARK: - Pinch Gesture Detection
    
    private func detectPinchGesture(_ chirality: HandAnchor.Chirality,
                                   _ currentDistance: Float,
                                   _ indexPosition: SIMD3<Float>) {
        let now = Date()
        guard now.timeIntervalSince(lastPinchTime) > pinchCooldown else { return }
        
        switch chirality {
        case .left:
            handleLeftHandPinch(currentDistance: currentDistance,
                              indexPosition: indexPosition,
                              now: now)
        case .right:
            handleRightHandPinch(currentDistance: currentDistance, now: now)
        }
    }
    
    private func handleLeftPinch() {
        myEntities.placeMeasurement()
        print("Measurement placed via left hand pinch")
    }
    
    private func handleRightPinch() {
        myEntities.removeLastMeasurement()
        print("Last measurement removed via right hand pinch")
    }
    
    // MARK: - Annotation Management
    
    private func handleAnnotationPinch(at position: SIMD3<Float>) {
        pendingAnnotationPosition = position
        print("Annotation pinch detected at position: \(position)")
    }
    
    private func handleAnnotationRemove() {
        annotationManager.removeLastAnnotation()
        print("Last annotation removed via right hand pinch")
    }
    
    func createAnnotationWithText(_ text: String) {
        guard let position = pendingAnnotationPosition else {
            print("No pending annotation position")
            return
        }
        
        let annotation = annotationManager.createAnnotation(at: position, text: text)
        myEntities.addAnnotation(annotation)
        pendingAnnotationPosition = nil
        
        print("Annotation created with text: '\(text)' at position: \(position)")
    }
    
    func cancelPendingAnnotation() {
        pendingAnnotationPosition = nil
    }
    
    // MARK: - Public Measurement Methods
    
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
    
    // MARK: - Public Annotation Methods
    
    func placeAnnotation(at position: SIMD3<Float>, text: String = "") {
        let annotation = annotationManager.createAnnotation(at: position, text: text)
        myEntities.addAnnotation(annotation)
        print("Annotation placed at: \(position)")
    }
    
    func removeLastAnnotation() {
        guard let lastAnnotation = annotationManager.getAllAnnotations().last else { return }
        annotationManager.removeAnnotation(id: lastAnnotation.id)
        myEntities.removeAnnotation(id: lastAnnotation.id)
    }
    
    func clearAllAnnotations() {
        let allAnnotations = annotationManager.getAllAnnotations()
        allAnnotations.forEach { annotation in
            myEntities.removeAnnotation(id: annotation.id)
        }
        annotationManager.clearAllAnnotations()
        print("🧹 All annotations cleared")
    }
    
    //MARK: - Angle Detectino MEthods
    
    
    // MARK: - Debug Methods
    
    func getPinchStatus() -> String {
        let leftStatus = leftWasPinched ? "PINCHED" : String(format: "%.1fcm", leftPinchDistance * 100)
        let rightStatus = rightWasPinched ? "PINCHED" : String(format: "%.1fcm", rightPinchDistance * 100)
        return "L: \(leftStatus) | R: \(rightStatus)"
    }
    
    // MARK: - Unused Angle Measurement (Consider removing)
    
    private func handleLeftHandPinch(currentDistance: Float,
                                    indexPosition: SIMD3<Float>,
                                    now: Date) {
        let isPinched = currentDistance < pinchThreshold
        
        if !leftWasPinched && isPinched {
            switch gestureMode {
            case .measure:
                handleLeftPinch()
            case .annotate:
                handleAnnotationPinch(at: indexPosition)
            case .angle:
                handleAngleLeftPinch(at: indexPosition)
            default:
                break
            }
            lastPinchTime = now
        }
        
        leftWasPinched = isPinched
        leftPinchDistance = currentDistance
    }

    // In handleRightHandPinch method, add angle case:
    private func handleRightHandPinch(currentDistance: Float, now: Date) {
        let isPinched = currentDistance < pinchThreshold
        
        if !rightWasPinched && isPinched {
            switch gestureMode {
            case .measure:
                handleRightPinch()
            case .annotate:
                handleAnnotationRemove()
            case .angle:
                handleAngleRightPinch()
            default:
                break
            }
            lastPinchTime = now
        }
        
        rightWasPinched = isPinched
        rightPinchDistance = currentDistance
    }

    // Replace the existing handleAngleLeftPinch method with this:
    private func handleAngleLeftPinch(at position: SIMD3<Float>) {
        // Left pinch: Place the reference line using current finger positions
        guard let leftPos = myEntities.fingerTips[.left]?.position,
              let rightPos = myEntities.fingerTips[.right]?.position else {
            print("⚠️ Cannot get finger positions")
            return
        }
        
        guard isTracked(leftPos), isTracked(rightPos) else {
            print("⚠️ Hands not tracked")
            return
        }
        
        // Place a reference line between both hands
        myEntities.placeAngleReferenceLine(leftPos: leftPos, rightPos: rightPos)
    }

    private func handleAngleRightPinch() {
        // Right pinch: Complete the angle measurement or remove last
        if myEntities.hasActiveAngleReference {
            // If there's an active reference line, complete the measurement
            guard let rightPos = myEntities.fingerTips[.right]?.position else {
                return
            }
            
            guard isTracked(rightPos) else {
                return
            }
            
            // Use right hand position to complete the angle
            myEntities.completeAngleWithRightHand(rightPos: rightPos)
        } else {
            // If no active reference, remove the last completed angle
            myEntities.removeLastAngle()
        }
    }

    // Make sure you have this helper method (should already exist):
    private func isTracked(_ position: SIMD3<Float>) -> Bool {
        let trackingThreshold: Float = -999
        return position.x > trackingThreshold &&
               position.y > trackingThreshold &&
               position.z > trackingThreshold
    }

    // Add public methods for angle management:
    func clearAllAngles() {
        myEntities.clearAllAngles()
        print("🧹 All angles cleared")
    }
}
>>>>>>> Stashed changes
