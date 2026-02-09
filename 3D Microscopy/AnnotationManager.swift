//
//  AnnotationManager.swift
//  3D Microscopy
//
//  Created by FutureLab XR2 on 11/17/25.
//

//
//  AnnotationManager.swift
//  3D Microscopy
//
//  Created by FutureLab XR2 on 7/9/25.
//

import SwiftUI
import RealityKit

// MARK: - AnnotationNote

struct AnnotationNote: Identifiable {
    let id: UUID
    let entity: Entity
    let position: SIMD3<Float>
    var text: String
    let timestamp: Date
    
    init(position: SIMD3<Float>, text: String = "Note") {
        self.id = UUID()
        self.position = position
        self.text = text
        self.timestamp = Date()
        self.entity = Self.createAnnotationEntity(position: position, text: text)
    }
    
    private static func createAnnotationEntity(position: SIMD3<Float>, text: String) -> Entity {
        let containerEntity = Entity()
        containerEntity.position = position
        
        // Create pin/marker sphere
        let markerSphere = ModelEntity(
            mesh: .generateSphere(radius: 0.01),
            materials: [SimpleMaterial(color: .systemYellow, roughness: 0.2, isMetallic: false)]
        )
        
        // Create text label
        let textEntity = Entity()
        textEntity.position = SIMD3<Float>(0, 0.03, 0) // Position above marker
        
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.015),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        textEntity.components.set(ModelComponent(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .white, roughness: 0.1, isMetallic: false)]
        ))
        
        // Make text always face user
        textEntity.components.set(BillboardComponent())
        
        // Assemble
        containerEntity.addChild(markerSphere)
        containerEntity.addChild(textEntity)
        
        return containerEntity
    }
}

// MARK: - AnnotationManager

@MainActor
class AnnotationManager: ObservableObject {
    
    @Published private var annotations: [AnnotationNote] = []
    
    var maxStoredAnnotations: Int = 50
    
    // MARK: - Public Methods
    
    func createAnnotation(at position: SIMD3<Float>, text: String = "Note") -> AnnotationNote {
        let annotation = AnnotationNote(position: position, text: text)
        annotations.append(annotation)
        
        // Remove oldest if exceeding limit
        if annotations.count > maxStoredAnnotations {
            annotations.removeFirst()
        }
        
        print("📌 Created annotation #\(annotations.count): '\(text)' at \(position)")
        return annotation
    }
    
    func removeAnnotation(id: UUID) {
        if let index = annotations.firstIndex(where: { $0.id == id }) {
            let removed = annotations.remove(at: index)
            print("🗑️ Removed annotation: '\(removed.text)'")
        }
    }
    
    func removeLastAnnotation() {
        guard !annotations.isEmpty else {
            print("⚠️ No annotations to remove")
            return
        }
        let removed = annotations.removeLast()
        print("🗑️ Removed last annotation: '\(removed.text)'")
    }
    
    func clearAllAnnotations() {
        let count = annotations.count
        annotations.removeAll()
        print("🧹 Cleared all \(count) annotations")
    }
    
    func getAllAnnotations() -> [AnnotationNote] {
        return annotations
    }
    
    func getAnnotation(id: UUID) -> AnnotationNote? {
        return annotations.first { $0.id == id }
    }
    
    var annotationCount: Int {
        return annotations.count
    }
    
    func getAnnotationSummary() -> String {
        let count = annotations.count
        if count == 0 {
            return "Pinch to place annotation"
        } else if count == 1 {
            return "1 annotation placed"
        } else {
            return "\(count) annotations placed"
        }
    }
    
    // MARK: - Update Methods
    
    func updateAnnotationText(id: UUID, newText: String) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else {
            print("⚠️ Annotation not found: \(id)")
            return
        }
        
        annotations[index].text = newText
        print("✏️ Updated annotation text to: '\(newText)'")
    }
    
    // MARK: - Statistics
    
    func getAnnotationStats() -> (count: Int, oldest: Date?, newest: Date?) {
        guard !annotations.isEmpty else {
            return (count: 0, oldest: nil, newest: nil)
        }
        
        let timestamps = annotations.map { $0.timestamp }
        let oldest = timestamps.min()
        let newest = timestamps.max()
        
        return (count: annotations.count, oldest: oldest, newest: newest)
    }
}
