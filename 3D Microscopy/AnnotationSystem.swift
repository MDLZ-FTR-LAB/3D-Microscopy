//
//  AnnotationNote.swift
//  3D Microscopy
//
//  Created by Future Lab on 7/29/25.
//  Annotation system for placing sticky notes on 3D models
 
import SwiftUI
import RealityKit
import Foundation
 
// MARK: - Annotation Data Structure
struct AnnotationNote {
    let id: UUID
    let entity: Entity // Container for the annotation
    let noteEntity: Entity // The sticky note visual
    let textEntity: Entity // The text content
    let position: SIMD3<Float>
    let text: String
    let timestamp: Date
    let color: UIColor
    
    init(position: SIMD3<Float>, text: String, color: UIColor = .systemYellow) {
        self.id = UUID()
        self.position = position
        self.text = text
        self.timestamp = Date()
        self.color = color
        
        // Create container entity
        let containerEntity = Entity()
        containerEntity.position = position
        
        // Create the sticky note background
        let noteEntity = Entity()
        let noteSize: Float = 0.08
        let noteThickness: Float = 0.002
        
        noteEntity.components.set(ModelComponent(
            mesh: .generateBox(
                width: noteSize,
                height: noteSize,
                depth: noteThickness,
                cornerRadius: 0.005
            ),
            materials: [SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)]
        ))
        
        // Add a slight shadow/border effect
        let shadowEntity = Entity()
        shadowEntity.position = SIMD3<Float>(0.001, -0.001, -0.001)
        shadowEntity.components.set(ModelComponent(
            mesh: .generateBox(
                width: noteSize + 0.002,
                height: noteSize + 0.002,
                depth: noteThickness,
                cornerRadius: 0.005
            ),
            materials: [SimpleMaterial(color: .black.withAlphaComponent(0.3), roughness: 0.5, isMetallic: false)]
        ))
        shadowEntity.components.set(OpacityComponent(opacity: 0.3))
        
        // Create text entity
        let textEntity = Entity()
        let displayText = text.isEmpty ? "📝" : text
        
        do {
            let textMesh = MeshResource.generateText(
                displayText,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.012, weight: .medium),
                containerFrame: CGRect(x: 0, y: 0, width: 0.07, height: 0.07),
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            
            textEntity.components.set(ModelComponent(
                mesh: textMesh,
                materials: [SimpleMaterial(color: .black, roughness: 0.1, isMetallic: false)]
            ))
        } catch {
            print("Failed to create text mesh: \(error)")
            // Fallback to emoji if text creation fails
            let fallbackMesh = MeshResource.generateText(
                "📝",
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.02),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            textEntity.components.set(ModelComponent(
                mesh: fallbackMesh,
                materials: [SimpleMaterial(color: .black, roughness: 0.1, isMetallic: false)]
            ))
        }
        
        // Position text directly on the sticky note (only slight z-offset)
        textEntity.position = SIMD3<Float>(0, 0, noteThickness/2 + 0.0005)
        
        // Make the entire annotation billboard (always face user)
        containerEntity.components.set(BillboardComponent())
        
        // Ensure annotations don't block interaction with the model
        // Remove any input target components to prevent interference
        containerEntity.components.remove(InputTargetComponent.self)
        noteEntity.components.remove(InputTargetComponent.self)
        textEntity.components.remove(InputTargetComponent.self)
        shadowEntity.components.remove(InputTargetComponent.self)
        
        // Assembly
        containerEntity.addChild(shadowEntity)
        containerEntity.addChild(noteEntity)
        containerEntity.addChild(textEntity)
        
        self.entity = containerEntity
        self.noteEntity = noteEntity
        self.textEntity = textEntity
    }
    
    // Update the text content of an existing annotation
    mutating func updateText(_ newText: String) {
        let displayText = newText.isEmpty ? "📝" : newText
        
        do {
            let textMesh = MeshResource.generateText(
                displayText,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.012, weight: .medium),
                containerFrame: CGRect(x: 0, y: 0, width: 0.07, height: 0.07),
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            
            textEntity.components.set(ModelComponent(
                mesh: textMesh,
                materials: [SimpleMaterial(color: .black, roughness: 0.1, isMetallic: false)]
            ))
        } catch {
            print("Failed to update text mesh: \(error)")
        }
    }
}
 
// MARK: - Annotation Manager
@MainActor
class AnnotationManager: ObservableObject {
    private var annotations: [AnnotationNote] = []
    private let maxAnnotations: Int = 50
    
    @Published var selectedAnnotationID: UUID?
    @Published var isEditingAnnotation = false
    @Published var editingText = ""
    
    // Colors for different annotation types
    let availableColors: [UIColor] = [
        .systemYellow,
        .systemBlue,
        .systemGreen,
        .systemOrange,
        .systemPink,
        .systemPurple
    ]
    private var currentColorIndex = 0
    
    // MARK: - Public Methods
    
    /// Create a new annotation at the specified position
    func createAnnotation(at position: SIMD3<Float>, text: String = "", color: UIColor? = nil) -> AnnotationNote {
        let annotationColor = color ?? availableColors[currentColorIndex]
        currentColorIndex = (currentColorIndex + 1) % availableColors.count
        
        let annotation = AnnotationNote(position: position, text: text, color: annotationColor)
        annotations.append(annotation)
        
        // Remove oldest if we exceed limit
        if annotations.count > maxAnnotations {
            let oldest = annotations.removeFirst()
            oldest.entity.removeFromParent()
        }
        
        return annotation
    }
    
    /// Remove an annotation by ID
    func removeAnnotation(id: UUID) -> Bool {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        let annotation = annotations.remove(at: index)
        annotation.entity.removeFromParent()
        
        if selectedAnnotationID == id {
            selectedAnnotationID = nil
            isEditingAnnotation = false
        }
        
        return true
    }
    
    /// Remove the most recently created annotation
    func removeLastAnnotation() -> Bool {
        guard let lastAnnotation = annotations.last else {
            return false
        }
        return removeAnnotation(id: lastAnnotation.id)
    }
    
    /// Clear all annotations
    func clearAllAnnotations() {
        annotations.forEach { $0.entity.removeFromParent() }
        annotations.removeAll()
        selectedAnnotationID = nil
        isEditingAnnotation = false
    }
    
    /// Get annotation by ID
    func getAnnotation(id: UUID) -> AnnotationNote? {
        return annotations.first { $0.id == id }
    }
    
    /// Get all annotations
    func getAllAnnotations() -> [AnnotationNote] {
        return annotations
    }
    
    /// Get annotation count
    var annotationCount: Int {
        return annotations.count
    }
    
    /// Update annotation text
    func updateAnnotationText(id: UUID, newText: String) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Note: Since AnnotationNote is a struct, we need to replace the entire annotation
        let oldAnnotation = annotations[index]
        oldAnnotation.entity.removeFromParent()
        
        let updatedAnnotation = AnnotationNote(
            position: oldAnnotation.position,
            text: newText,
            color: oldAnnotation.color
        )
        
        annotations[index] = updatedAnnotation
        
        // Re-add to scene if it was previously added
        // This will be handled by the parent system
    }
    
    /// Select an annotation for editing
    func selectAnnotation(id: UUID) {
        selectedAnnotationID = id
        if let annotation = getAnnotation(id: id) {
            editingText = annotation.text
            isEditingAnnotation = true
        }
    }
    
    /// Deselect current annotation
    func deselectAnnotation() {
        selectedAnnotationID = nil
        isEditingAnnotation = false
        editingText = ""
    }
    
    /// Save the currently edited text
    func saveEditingText() {
        guard let selectedID = selectedAnnotationID else { return }
        updateAnnotationText(id: selectedID, newText: editingText)
        deselectAnnotation()
    }
    
    /// Cancel editing
    func cancelEditing() {
        deselectAnnotation()
    }
    
    // MARK: - Statistics and Info and Info
    
    /// Get summary of annotations
    func getAnnotationSummary() -> String {
        let count = annotations.count
        if count == 0 {
            return "No annotations"
        } else if count == 1 {
            return "1 annotation"
        } else {
            return "\(count) annotations"
        }
    }
    
    /// Export annotations as text
    func exportAnnotationsAsText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var export = "3D Microscopy Annotations\n"
        export += "Exported: \(formatter.string(from: Date()))\n"
        export += "Total: \(annotations.count) annotations\n\n"
        
        for (index, annotation) in annotations.enumerated() {
            export += "[\(index + 1)] \(formatter.string(from: annotation.timestamp))\n"
            export += "Position: (\(String(format: "%.3f", annotation.position.x)), \(String(format: "%.3f", annotation.position.y)), \(String(format: "%.3f", annotation.position.z)))\n"
            export += "Text: \(annotation.text.isEmpty ? "(empty)" : annotation.text)\n\n"
        }
        
        return export
    }
}
 
