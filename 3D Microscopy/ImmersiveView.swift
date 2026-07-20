
//
//  ImmersiveView.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

import SwiftUI
import RealityKit
import simd

struct ImmersiveView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject var actionUndoManager: ActionUndoManager
    @State private var modelEntity: Entity? = nil
    @Environment(\.openWindow) private var openWindow
    
    //vars for drag gesture
    @GestureState private var dragOffset: CGSize = .zero
    @State private var lastDragPosition: SIMD3<Float>? = nil
    
    // Add a state variable to force RealityView updates
    @State private var updateTrigger: Bool = false
    @State private var scaleStart: SIMD3<Float>? = nil
    
    // Rotation tracking for multiaxial rotation
    @State private var lastRotationDragLocation: CGPoint? = nil
    @State private var accumulatedRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    
    // Store transform at gesture start for undo
    @State private var transformAtGestureStart: Transform? = nil
    
    var body: some View {
        gestureWrapper(for: modelEntity) {
            RealityView { content, attachments in
                // Add hand-tracking root entities
                if appModel.isOn {
                    print("Adding measuring bar root entity")
                    content.add(appModel.myEntities.root)
                }
                // Add model once it's loaded
                if let entity = modelEntity {
                    print("added model")
                    content.add(entity)
                }
                
                // Add result board overlay if available
                if let board = attachments.entity(for: "resultBoard") {
                    appModel.myEntities.add(board)
                }
            } update: { content, attachments in
                // This update block runs when updateTrigger changes
                
                // Clear existing content except for hand tracking
                content.entities.removeAll { entity in
                    entity != appModel.myEntities.root
                }
                
                // Re-add model if it exists
                if let entity = modelEntity {
                    content.add(entity)
                }
                
                // Handle hand tracking visibility
                if appModel.isOn && !content.entities.contains(appModel.myEntities.root) {
                    content.add(appModel.myEntities.root)
                } else if !appModel.isOn && content.entities.contains(appModel.myEntities.root) {
                    content.remove(appModel.myEntities.root)
                }
            } attachments: {
                // Attachment for floating result display
                Attachment(id: "resultBoard") {
                    if appModel.gestureMode != .angle {
                        Text(appModel.resultString)
                            .monospacedDigit()
                            .padding()
                            .glassBackgroundEffect()
                            .offset(y: -80)
                    }
                }
            }
        }
        // Add updateTrigger as an id to force RealityView updates
        .id(updateTrigger)
        // Kick off hand‐tracking session and anchor updates
        .task {
            await appModel.runSession()
        }
        .task {
            // Process anchor updates continuously
            await appModel.processAnchorUpdates()
        }
        // Watch for modelURL changes and load model
        .task(id: appModel.modelURL) {
            // Load model if not already loaded and modelURL exists
            if let modelURL = appModel.modelURL {
                do {
                    let rawEntity = try await ModelEntity(contentsOf: modelURL)
                    rawEntity.components.set(InputTargetComponent())
                    rawEntity.generateCollisionShapes(recursive: true)
                    let wrappedEntity = centerEntity(rawEntity)
                    wrappedEntity.setPosition([0, 1, -1], relativeTo: nil)
                    modelEntity = wrappedEntity
                    
                    // Reset accumulated rotation for new model
                    accumulatedRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                    
                    // Toggle updateTrigger to force RealityView to re-render
                    updateTrigger.toggle()
                    
                    print("Model loaded !!")
                } catch {
                    print("Failed to load model: \(error.localizedDescription)")
                }
            }
        }
        // Watch for changes to isOn and trigger update
        .onChange(of: appModel.isOn) { _, _ in
            updateTrigger.toggle()
        }
        // Watch for gesture mode changes
        .onChange(of: appModel.gestureMode) { _, newMode in
            if newMode == .angle {
                appModel.myEntities.isAngleMode = true
                appModel.myEntities.showAngles()
            }
            else if newMode == .measure {
                appModel.myEntities.isAngleMode = false
                appModel.myEntities.showMeasurements()
            }

            updateTrigger.toggle()
        }
    }
    
    // Center the model by wrapping it in an anchor
    func centerEntity(_ entity: Entity) -> Entity {
        let anchor = Entity()
        let bounds = entity.visualBounds(relativeTo: nil)
        let center = bounds.center
        entity.position -= center
        anchor.addChild(entity)
        return anchor
    }
    
    // Custom gesture wrapper for different modes
    @ViewBuilder
    func gestureWrapper<Content: View>(for entity: Entity?, @ViewBuilder content: () -> Content) -> some View {
        switch appModel.gestureMode {
        case .drag:
            content()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard let entity = entity else { return }
                            
                            // Capture transform at start of gesture for undo
                            if transformAtGestureStart == nil {
                                transformAtGestureStart = entity.transform
                            }
                            
                            let currentX = Float(value.translation.width)
                            let currentY = Float(value.translation.height)
                            
                            let lastX = lastDragPosition?.x ?? 0
                            let lastY = lastDragPosition?.y ?? 0
                            
                            // Horizontal drag → X axis, Vertical drag → Y axis (inverted)
                            let deltaX = (currentX - lastX) * 0.001
                            let deltaY = (lastY - currentY) * 0.001
                            
                            entity.position += SIMD3<Float>(deltaX, deltaY, 0)
                            
                            lastDragPosition = SIMD3<Float>(currentX, currentY, 0)
                        }
                        .onEnded { _ in
                            // Push undo action with the transform before this drag started
                            if let entity = entity, let startTransform = transformAtGestureStart {
                                actionUndoManager.push(.transformChanged(entity: entity, previousTransform: startTransform))
                            }
                            lastDragPosition = nil
                            transformAtGestureStart = nil
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard let entity = entity else { return }
                            // Use pinch in drag mode to move along Z axis
                            let zDelta = Float(value - 1.0) * 0.01
                            entity.position += SIMD3<Float>(0, 0, -zDelta)
                        }
                )
            
        case .rotate:
            content().gesture(
                DragGesture()
                    .onChanged { value in
                        guard let entity = entity else { return }
                        
                        // Capture transform at start of gesture for undo
                        if transformAtGestureStart == nil {
                            transformAtGestureStart = entity.transform
                        }
                        
                        let currentLocation = CGPoint(
                            x: value.translation.width,
                            y: value.translation.height
                        )
                        
                        let lastLocation = lastRotationDragLocation ?? .zero
                        
                        // Calculate deltas since last frame
                        let deltaX = Float(currentLocation.x - lastLocation.x)
                        let deltaY = Float(currentLocation.y - lastLocation.y)
                        
                        let sensitivity: Float = 0.005
                        
                        // Horizontal drag → rotate around Y axis
                        let yRotation = simd_quatf(angle: deltaX * sensitivity, axis: SIMD3<Float>(0, 1, 0))
                        
                        // Vertical drag → rotate around X axis
                        let xRotation = simd_quatf(angle: deltaY * sensitivity, axis: SIMD3<Float>(1, 0, 0))
                        
                        // Combine: apply Y rotation then X rotation to accumulated
                        accumulatedRotation = yRotation * xRotation * accumulatedRotation
                        entity.transform.rotation = accumulatedRotation
                        
                        lastRotationDragLocation = currentLocation
                    }
                    .onEnded { _ in
                        // Push undo action with the transform before this rotation started
                        if let entity = entity, let startTransform = transformAtGestureStart {
                            actionUndoManager.push(.transformChanged(entity: entity, previousTransform: startTransform))
                        }
                        lastRotationDragLocation = nil
                        transformAtGestureStart = nil
                    }
            )
            
        case .scale:
            content().gesture(
                MagnificationGesture()
                    .onChanged { value in
                        guard let entity = entity else { return }

                        // Capture transform at start of gesture for undo
                        if scaleStart == nil {
                            scaleStart = entity.transform.scale
                            transformAtGestureStart = entity.transform
                        }

                        let start = scaleStart ?? entity.transform.scale
                        let m = Float(value) // value starts near 1.0 for each new pinch

                        entity.transform.scale = start * SIMD3<Float>(repeating: m)
                    }
                    .onEnded { _ in
                        // Push undo action with the transform before this scale started
                        if let entity = entity, let startTransform = transformAtGestureStart {
                            actionUndoManager.push(.transformChanged(entity: entity, previousTransform: startTransform))
                        }
                        scaleStart = nil
                        transformAtGestureStart = nil
                    }
            )
            
        case .measure:
            content()
            // Just use content(). Adding .gesture() will make a second line appear.
        
        case .angle:
            content()
            
        default:
            content() // No gesture
        }
    }
}

