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
    @State private var modelEntity: Entity? = nil
    @Environment(\.openWindow) private var openWindow
    
    //vars for drag gesture
    @GestureState private var dragOffset: CGSize = .zero
    @State private var lastDragPosition: SIMD3<Float>? = nil
    
    // Add a state variable to force RealityView updates
    @State private var updateTrigger: Bool = false
    @State private var scaleStart: SIMD3<Float>? = nil // Isabella
    
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
                
                // Add annotation controls overlay for annotation mode
                if let controls = attachments.entity(for: "annotationControls") {
                    controls.position = [0.5, 0.3, -0.5] // Position in front of user
                    content.add(controls)
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
                
                // Update annotation controls visibility
                if let controls = attachments.entity(for: "annotationControls") {
                    if appModel.gestureMode == .annotate && appModel.isOn {
                        controls.position = [0.5, 0.3, -0.5]
                        if !content.entities.contains(controls) {
                            content.add(controls)
                        }
                    } else {
                        content.remove(controls)
                    }
                }
            } attachments: {
                // Attachment for floating result display
                Attachment(id: "resultBoard") {
                    Text(appModel.resultString)
                        .monospacedDigit()
                        .padding()
                        .glassBackgroundEffect()
                        .offset(y: -80)
                }
                
                // Attachment for annotation controls (only visible in annotation mode)
                if appModel.gestureMode == .annotate {
                    Attachment(id: "annotationControls") {
                        AnnotationControlsView(annotationManager: appModel.annotationManager)
                            .environmentObject(appModel)
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
        .onChange(of: appModel.gestureMode) { _, _ in
            updateTrigger.toggle()
        }
        // Handle pending annotation creation
        .onChange(of: appModel.pendingAnnotationPosition) { _, newPosition in
            if newPosition != nil {
                // Open annotation input window when a new annotation is requested
                openWindow(id: "AnnotationInput")
            }
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
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onChanged { value in
                            guard let entity = entity else { return }
                            
                            let currentX = Float(value.translation.width)
                            let currentZ = Float(value.translation.height)
                            
                            let lastX = lastDragPosition?.x ?? 0
                            let lastZ = lastDragPosition?.z ?? 0
                            
                            let deltaX = (currentX - lastX) * 0.001
                            let deltaZ = (lastZ - currentZ) * 0.001
                            
                            entity.position += SIMD3<Float>(deltaX, 0, deltaZ)
                            
                            lastDragPosition = SIMD3<Float>(currentX, 0, currentZ)
                        }
                        .onEnded { _ in
                            lastDragPosition = nil
                        }
                )
            
        case .rotate:
            content().gesture(
                DragGesture()
                    .onChanged { value in
                        guard let entity = entity else { return }
                        let sensitivity: Float = 0.001
                        let angle = Float(value.translation.width) * sensitivity
                        let rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
                        entity.transform.rotation = rotation * entity.transform.rotation
                    }
            )
            
        case .scale:
            content().gesture(
                MagnificationGesture().onChanged { value in
                    // Roshni's code below:
//                    if let entity = entity {
//                        entity.transform.scale = [Float(value), Float(value), Float(value)]
//                    }
                    // Isabella's code below:
                    guard let entity = entity else { return }

                    // Capture the scale once per pinch gesture
                    if scaleStart == nil {
                        scaleStart = entity.transform.scale
                    }

                    let start = scaleStart ?? entity.transform.scale
                    let m = Float(value) // value starts near 1.0 for each new pinch

                    entity.transform.scale = start * SIMD3<Float>(repeating: m)
                }
                .onEnded { _ in
                    // End of pinch: keep the final scale, reset only the baseline
                    scaleStart = nil
                }
            )
            
        case .measure:
            content()
                .gesture(
                    // Single tap to place measurement
                    TapGesture()
                        .onEnded { _ in
                            appModel.myEntities.placeMeasurement()
                        }
                )
                .gesture(
                    // Double tap to remove last measurement
                    TapGesture(count: 2)
                        .onEnded { _ in
                            appModel.myEntities.removeLastMeasurement()
                        }
                )
                .gesture(
                    // Long press to clear all measurements
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            appModel.myEntities.clearAllMeasurements()
                        }
                )
            
        case .annotate:
            content()
                .onTapGesture { location in
                    // Handle tap on existing annotations or create new ones
                    // For now, we rely on pinch gestures for annotation creation
                    // This could be extended to handle tap-to-select annotations
                    print("Tap in annotation mode at: \(location)")
                }
                .gesture(
                    // Long press to clear all annotations
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            appModel.clearAllAnnotations()
                        }
                )
            
            // MARK: - Improved Crop Gesture Implementation
            
        case .crop:
            content()
                .gesture(
                    DragGesture(minimumDistance: 10) // Reduced minimum distance
                        .onChanged { value in
                            print("🔄 Drag detected - translation: \(value.translation)")
                            guard let entity = entity else {
                                print("❌ No entity found")
                                return
                            }
                            
                            if !appModel.isDrawingCropLine {
                                print("✅ Starting crop line drawing")
                                appModel.isDrawingCropLine = true
                                appModel.cropStartPoint = convertScreenToWorld(value.startLocation, entity: entity)
                                createSimpleCropPreview(entity: entity)
                            }
                            
                            appModel.cropEndPoint = convertScreenToWorld(value.location, entity: entity)
                            updateSimpleCropPreview(entity: entity)
                        }
                        .onEnded { value in
                            print("🎯 Drag ended - applying crop")
                            guard let entity = entity else {
                                print("❌ No entity found for crop")
                                return
                            }
                            
                            // Simple demo: just apply the crop effect
                            applyDemoCrop(to: entity)
                            
                            // Cleanup
                            appModel.cleanupCropPreview()
                            appModel.isDrawingCropLine = false
                            appModel.cropStartPoint = nil
                            appModel.cropEndPoint = nil
                        }
                )
            
            
        default:
            content() // No gesture
        }
    }
    
    // MARK: - Simple Preview (just a line)
    func createSimpleCropPreview(entity: Entity) {
        appModel.cleanupCropPreview()
        
        // Create a simple red line
        let material = UnlitMaterial(color: .red)
        let mesh = MeshResource.generateBox(size: [0.01, 0.01, 0.5])
        
        appModel.cropPreviewEntity = ModelEntity(mesh: mesh, materials: [material])
        
        if let parent = entity.parent {
            parent.addChild(appModel.cropPreviewEntity!)
        }
    }
    
    func updateSimpleCropPreview(entity: Entity) {
        guard let previewEntity = appModel.cropPreviewEntity,
              let startPoint = appModel.cropStartPoint,
              let endPoint = appModel.cropEndPoint else { return }
        
        let center = (startPoint + endPoint) / 2
        let length = distance(startPoint, endPoint)
        
        previewEntity.position = center
        previewEntity.transform.scale = SIMD3<Float>(1, 1, max(length, 0.1))
    }
    
    // MARK: - Demo Crop Effect (Simple Transform)
    
    func createClippingMaterial(for entity: ModelEntity) {
        // Skip the custom material approach - use the simpler alternatives instead
        // The CustomMaterial API is complex and varies between OS versions
        
        // Fall back to the simple scaling method
        applyDemoCropSuperSimple(to: entity)
    }
    
    // MARK: - Even Simpler Alternative - Just Scale and Clone
    func applyDemoCropAlternative(to entity: Entity) {
        guard let modelEntity = entity as? ModelEntity else { return }
        
        // Create a simple "cropped" effect by scaling and positioning
        // This avoids all material API issues
        
        // Method 1: Just scale the original
        modelEntity.transform.scale = SIMD3<Float>(0.6, 1, 1) // Scale down in X
        modelEntity.position += SIMD3<Float>(-0.05, 0, 0) // Slight offset
        
        // Method 2: If you want to show "two pieces", create a duplicate
        if let parent = modelEntity.parent {
            let secondPiece = modelEntity.clone(recursive: true)
            secondPiece.transform.scale = SIMD3<Float>(0.3, 1, 1) // Smaller piece
            secondPiece.position = modelEntity.position + SIMD3<Float>(0.2, 0, 0) // Offset right
            parent.addChild(secondPiece)
        }
        
        print("Demo crop applied - model split with scaling!")
    }
    
    // MARK: - Super Simple Version - Create Cut Effect
    func applyDemoCropSuperSimple(to entity: Entity) {
        print("🔧 Applying demo crop to entity: \(entity.name)")
        
        // Find the ModelEntity - it might be a child of the wrapper entity
        var modelEntity: ModelEntity?
        
        if let directModel = entity as? ModelEntity {
            modelEntity = directModel
            print("✅ Entity is directly a ModelEntity")
        } else {
            // Look for ModelEntity in children (from centerEntity wrapper)
            for child in entity.children {
                if let childModel = child as? ModelEntity {
                    modelEntity = childModel
                    print("✅ Found ModelEntity in children: \(child.name)")
                    break
                }
            }
        }
        
        guard let model = modelEntity else {
            print("❌ No ModelEntity found in entity or its children")
            return
        }
        
        print("✅ Before crop - scale: \(model.transform.scale), position: \(model.position)")
        
        // Create a "cut" effect by cloning the model and positioning pieces
        let leftPiece = model.clone(recursive: true)
        let rightPiece = model.clone(recursive: true)
        
        // Keep the same scale as original
        let originalScale = model.transform.scale
        leftPiece.transform.scale = originalScale
        rightPiece.transform.scale = originalScale
        
        // Position the pieces to show a "cut"
        leftPiece.position = model.position + SIMD3<Float>(-0.05, 0, 0) // Move left piece slightly left
        rightPiece.position = model.position + SIMD3<Float>(0.1, 0, 0)  // Move right piece away (like it was cut off)
        
        // Make right piece much smaller to show it was "cropped away"
        rightPiece.transform.scale = originalScale * 0.3 // Much smaller
        
        // Add both pieces to the parent
        if let parent = model.parent {
            parent.addChild(leftPiece)
            parent.addChild(rightPiece)
            
            // Remove the original
            model.removeFromParent()
            
            print("✅ Created left and right pieces")
            print("🎉 Demo crop applied - model appears cut!")
        } else {
            print("❌ Model has no parent to add pieces to")
        }
    }
    
    // MARK: - Choose Your Demo Method
    func applyDemoCrop(to entity: Entity) {
        print("🔧 Replacing model with cropped version")

        // Save world transform
        let worldTransform = entity.transformMatrix(relativeTo: nil)

        guard let parent = entity.parent else {
            print("❌ No parent entity found")
            return
        }

        // Remove all children recursively
        recursivelyRemoveAllModelEntities(from: entity)

        // Remove the parent entity itself
        entity.removeFromParent()

        // Load the cropped model and place it exactly in same position
        Task {
            do {
                let croppedEntity = try await Entity(named: "left1")

                // Apply original world transform
                croppedEntity.setTransformMatrix(worldTransform, relativeTo: nil)

                // Add new model
                parent.addChild(croppedEntity)
                print("✅ Replaced with cropped model at same position")
            } catch {
                print("❌ Failed to load cropped model: \(error)")
            }
        }
    }
    func recursivelyRemoveAllModelEntities(from entity: Entity) {
        for child in entity.children {
            recursivelyRemoveAllModelEntities(from: child)
        }
        print("🗑️ Removing: \(entity.name) [\(type(of: entity))]")
        entity.removeFromParent()
    }



    // MARK: - Simplified coordinate conversion for demo
    func convertScreenToWorld(_ screenPoint: CGPoint, entity: Entity) -> SIMD3<Float> {
        let bounds = entity.visualBounds(relativeTo: entity.parent)
        let center = bounds.center
        let size = bounds.max - bounds.min
        
        // Simple mapping - just use screen coordinates relative to entity
        let normalizedX = Float(screenPoint.x / 500.0 - 1.0) // Assume 500pt screen width
        let normalizedZ = Float(screenPoint.y / 500.0 - 1.0) // Assume 500pt screen height
        
        return SIMD3<Float>(
            center.x + normalizedX * size.x * 0.5,
            center.y,
            center.z + normalizedZ * size.z * 0.5
        )
    }
}
