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
    case none, drag, rotate, scale, measure, annotate, crop
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
        print("Last annotation removed via right hand pinch")
    }
    
    /// Create annotation at pending position with given text
    func createAnnotationWithText(_ text: String) {
        guard let position = pendingAnnotationPosition else {
            print("No pending annotation position")
            return
        }
        
        let annotation = annotationManager.createAnnotation(at: position, text: text)
        
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
