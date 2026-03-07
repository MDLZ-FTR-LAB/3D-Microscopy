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
    @State private var scaleStart: SIMD3<Float>? = nil
    
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
                    Text(appModel.resultString)
                        .monospacedDigit()
                        .padding()
                        .glassBackgroundEffect()
                        .offset(y: -80)
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
        .onChange(of: appModel.gestureMode) { _, newMode in
            
            if newMode == .angle {
                appModel.myEntities.isAngleMode = true
            } else {
                appModel.myEntities.isAngleMode = false
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
            // Just use content()!! Adding .gesture() will make a second line appear.
        
        case .angle:
            content()
            
        default:
            content() // No gesture
        }
    }
}
