
//
//  ImmersiveView.swift
//  3D Microscopy
//
//  Supports .usdz, .obj, and Gaussian Splat .ply files
//  with full gesture interaction (drag, rotate, scale, measure, angle)
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var undoManager: ActionUndoManager

    @State private var wrapperEntity = Entity()

    // Drag state
    @State private var lastDragValue: SIMD3<Float>?

    // Rotate state
    @State private var lastRotationX: Float = 0
    @State private var lastRotationY: Float = 0

    // Scale state
    @State private var initialScale: Float = 1.0
    
    @State private var scaleLabel = Entity()
    @State private var currentDisplayScale: Float = 1.0


    // Undo: captures transform BEFORE gesture starts
    @State private var preGestureTransform: Transform?
    
    @State private var slicePlaneVisualizer: SlicePlaneVisualizer?


    var body: some View {
        RealityView { content in
            wrapperEntity.position = SIMD3<Float>(0, 1.2, -1)
            content.add(wrapperEntity)

            // Add measurement/angle entities to the scene
            content.add(appModel.myEntities.root)
            
            // Scale label
               scaleLabel.components.set(BillboardComponent())
               scaleLabel.isEnabled = false
               content.add(scaleLabel)
            
            let visualizer = SlicePlaneVisualizer()
                content.add(visualizer.planeEntity)
                slicePlaneVisualizer = visualizer        }
        
        .task {
            await loadModel()
        }
        .task {
            await appModel.runSession()
        }
        .task {
            await appModel.processAnchorUpdates()
        }
        .task {
            await updateSlicePlane()
        }
       

        .gesture(pinchDragGesture)
        .gesture(scaleGesture)
        .onAppear {
            // Connect undo manager to app model
            appModel.undoManager = undoManager
        }
    }
    private func getIndexFingerData() -> (position: SIMD3<Float>, direction: SIMD3<Float>)? {
        guard let rightHand = appModel.rightHandAnchor,
              let skeleton = rightHand.handSkeleton else { return nil }

        let tipJoint = skeleton.joint(.indexFingerTip)
        let pipJoint = skeleton.joint(.indexFingerIntermediateBase)

        guard tipJoint.isTracked, pipJoint.isTracked else { return nil }

        let originFromWrist = rightHand.originFromAnchorTransform

        let tipTransform = originFromWrist * tipJoint.anchorFromJointTransform
        let pipTransform = originFromWrist * pipJoint.anchorFromJointTransform

        let tipPosition = SIMD3<Float>(
            tipTransform.columns.3.x,
            tipTransform.columns.3.y,
            tipTransform.columns.3.z
        )

        let pipPosition = SIMD3<Float>(
            pipTransform.columns.3.x,
            pipTransform.columns.3.y,
            pipTransform.columns.3.z
        )

        // Direction: from knuckle toward fingertip
        let direction = normalize(tipPosition - pipPosition)

        return (position: tipPosition, direction: direction)
    }

    private func updateSlicePlane() async {
        while true {
            if appModel.gestureMode == .slice {
                if let indexData = getIndexFingerData() {
                    slicePlaneVisualizer?.update(
                        fingerTipPosition: indexData.position,
                        fingerDirection: indexData.direction
                    )
                }
            } else {
                slicePlaneVisualizer?.hide()
            }

            try? await Task.sleep(nanoseconds: 16_666_667)
        }
    }
    
    // MARK: - Model Loading

    private func loadModel() async {
        wrapperEntity.children.forEach { $0.removeFromParent() }

        do {
            let entity: Entity
            var isSplat = false

            if let splatURL = appModel.splatURL {
                entity = try await loadSplatFromURL(splatURL)
                isSplat = true
                print("✅ Loaded Gaussian Splat: \(splatURL.lastPathComponent)")
            } else if let modelURL = appModel.modelURL {
                entity = try await ModelEntity(contentsOf: modelURL)
                print("✅ Loaded model: \(modelURL.lastPathComponent)")
            } else {
                print("⚠️ No model URL set")
                return
            }

            if isSplat {
                entity.scale = SIMD3<Float>(repeating: 0.1)
                configureSplatForInteraction(entity)

            } else {
                configureModelForInteraction(entity)
            }

            // Add to wrapper FIRST (so bounds can be computed in scene)
            wrapperEntity.addChild(entity)

            // Then center the USDZ model within the wrapper
            if !isSplat {
                // Use a brief delay to ensure bounds are resolved
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                let bounds = entity.visualBounds(relativeTo: wrapperEntity)
                let center = bounds.center

                print("📐 Bounds center: \(center), extents: \(bounds.extents)")

                // Only offset if bounds are reasonable
                if bounds.extents.x > 0 && bounds.extents.x < 1000 {
                    entity.position = -center
                    print("📐 Centered entity, new position: \(entity.position)")
                }
            }
        } catch {
            print("❌ Failed to load model: \(error)")
        }
    }

    // MARK: - Splat Loading

    private func loadSplatFromURL(_ url: URL) async throws -> Entity {
        let buffers = try await Task.detached(priority: .userInitiated) {
            let splatData = try readGaussianSplatFile(url)
            return try deinterleaveGaussianSplatData(splatData)
        }.value
        return try makeSplatEntity(from: buffers)
    }

    // MARK: - Entity Configuration (USDZ / OBJ)

    private func configureModelForInteraction(_ entity: Entity) {
        entity.components.set(InputTargetComponent(allowedInputTypes: .all))

        if let modelEntity = entity as? ModelEntity {
            modelEntity.generateCollisionShapes(recursive: true)
        } else {
            entity.generateCollisionShapes(recursive: true)
        }

        // Apply InputTargetComponent to all children so any part can be tapped
        func applyInputTarget(_ e: Entity) {
            e.components.set(InputTargetComponent(allowedInputTypes: .all))
            for child in e.children {
                applyInputTarget(child)
            }
        }
        applyInputTarget(entity)
    }

    // MARK: - Entity Configuration (Gaussian Splat)

    private func configureSplatForInteraction(_ entity: Entity) {
        entity.components.set(InputTargetComponent(allowedInputTypes: .all))
        entity.components.set(CollisionComponent(
            shapes: [.generateBox(size: SIMD3<Float>(repeating: 2.0))]
        ))
    }

    // MARK: - Pinch + Drag Gesture (routes to Drag or Rotate based on mode)

    private var pinchDragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                // Capture transform at the very start of the gesture
                if preGestureTransform == nil {
                    preGestureTransform = wrapperEntity.transform
                }

                switch appModel.gestureMode {
                case .drag:
                    handleDragChanged(value)
                case .rotate:
                    handleRotateChanged(value)
                default:
                    break
                }
            }
            .onEnded { value in
                switch appModel.gestureMode {
                case .drag:
                    handleDragEnded(value)
                case .rotate:
                    handleRotateEnded(value)
                default:
                    break
                }

                // Push undo with the ORIGINAL transform (before gesture started)
                if let original = preGestureTransform {
                    undoManager.push(.transformChanged(
                        entity: wrapperEntity,
                        previousTransform: original
                    ))
                }
                preGestureTransform = nil
            }
    }

    // MARK: - Drag Logic (always moves wrapperEntity)

    private func handleDragChanged(_ value: EntityTargetValue<DragGesture.Value>) {
        let sensitivity: Float = 0.001
        let current = SIMD3<Float>(
            Float(value.translation3D.x) * sensitivity,
            Float(-value.translation3D.y) * sensitivity,
            0
        )
        if let last = lastDragValue {
            let delta = current - last
            wrapperEntity.position += delta
        }
        lastDragValue = current
    }

    private func handleDragEnded(_ value: EntityTargetValue<DragGesture.Value>) {
        lastDragValue = nil
    }

    // MARK: - Rotate Logic (always rotates wrapperEntity)

    private func handleRotateChanged(_ value: EntityTargetValue<DragGesture.Value>) {
        let sensitivity: Float = 0.003

        let currentX = Float(value.translation3D.x) * sensitivity
        let currentY = Float(value.translation3D.y) * sensitivity

        // Delta-based rotation — avoids "further = faster" problem
        if lastRotationX != 0 || lastRotationY != 0 {
            let deltaX = currentX - lastRotationX
            let deltaY = currentY - lastRotationY

            // Horizontal drag → rotate around Y axis
            let horizontalRotation = simd_quatf(angle: deltaX, axis: SIMD3<Float>(0, 1, 0))
            // Vertical drag → rotate around X axis
            let verticalRotation = simd_quatf(angle: deltaY, axis: SIMD3<Float>(1, 0, 0))

            wrapperEntity.orientation = horizontalRotation * verticalRotation * wrapperEntity.orientation
        }

        lastRotationX = currentX
        lastRotationY = currentY
    }

    private func handleRotateEnded(_ value: EntityTargetValue<DragGesture.Value>) {
        lastRotationX = 0
        lastRotationY = 0
    }

    // MARK: - Scale Gesture (always scales wrapperEntity)

    private var scaleGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard appModel.gestureMode == GestureMode.scale else { return }

                if preGestureTransform == nil {
                    preGestureTransform = wrapperEntity.transform
                    initialScale = wrapperEntity.scale.x
                }

                let newScale = initialScale * Float(value.magnification)
                wrapperEntity.scale = SIMD3<Float>(repeating: newScale)

                // Update magnification label
                updateScaleLabel(newScale)
            }
            .onEnded { value in
                guard appModel.gestureMode == GestureMode.scale else { return }

                if let original = preGestureTransform {
                    undoManager.push(.transformChanged(
                        entity: wrapperEntity,
                        previousTransform: original
                    ))
                }
                initialScale = 1.0
                preGestureTransform = nil

                // Hide label after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    scaleLabel.isEnabled = false
                }
            }
    }

    private func updateScaleLabel(_ scale: Float) {
        // Calculate magnification relative to initial load scale (0.1)
        let magnification = scale / 0.1  // e.g. scale 0.2 = 2x, scale 1.0 = 10x

        let text: String
        if magnification < 1.0 {
            text = String(format: "%.1fx", magnification)
        } else if magnification < 10.0 {
            text = String(format: "%.1fx", magnification)
        } else {
            text = String(format: "%.0fx", magnification)
        }

        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.03, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        scaleLabel.components.set(ModelComponent(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .white, roughness: 0.1, isMetallic: false)]
        ))

        // Position above the model
        scaleLabel.position = wrapperEntity.position + SIMD3<Float>(0, 0.3, 0)
        scaleLabel.isEnabled = true
        currentDisplayScale = magnification
    }

}

