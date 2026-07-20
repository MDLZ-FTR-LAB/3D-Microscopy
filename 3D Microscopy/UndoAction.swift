//
//  UndoAction.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/15/26.
//



//
//  UndoManager.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

import SwiftUI
import RealityKit

// MARK: - Undo Action Types

enum UndoAction {
    /// Transform-based actions (drag, rotate, scale) — stores the entity and its previous transform
    case transformChanged(entity: Entity, previousTransform: Transform)
    
    /// A measurement was placed — undo removes it
    case placedMeasurement(measurement: MeasurementLine)
    
    /// A measurement was deleted — undo re-adds it
    case deletedMeasurement(measurement: MeasurementLine)
    
    /// An angle was placed — undo removes it
    case placedAngle(angle: MyEntities.AngleMeasurement)
    
    /// An angle was deleted — undo re-adds it
    case deletedAngle(angle: MyEntities.AngleMeasurement)
}

// MARK: - Undo Stack

@MainActor
class ActionUndoManager: ObservableObject {
    @Published private(set) var actions: [UndoAction] = []
    
    /// Maximum number of undo actions stored
    var maxActions: Int = 50
    
    /// Whether there are actions to undo
    var canUndo: Bool { !actions.isEmpty }
    
    /// Number of actions in the stack
    var count: Int { actions.count }
    
    /// Push a new action onto the undo stack
    func push(_ action: UndoAction) {
        actions.append(action)
        
        // Trim oldest if we exceed the limit
        if actions.count > maxActions {
            actions.removeFirst()
        }
    }
    
    /// Pop and execute the most recent undo action
    /// - Parameter myEntities: Reference to MyEntities for measurement/angle operations
    func undo(myEntities: MyEntities) {
        guard let action = actions.popLast() else { return }
        
        switch action {
        case .transformChanged(let entity, let previousTransform):
            // Restore the entity's previous position, rotation, and scale
            entity.transform = previousTransform
            
        case .placedMeasurement(let measurement):
            // Remove the measurement that was placed
            measurement.entity.removeFromParent()
            myEntities.removeMeasurementFromStorage(measurement)
            
        case .deletedMeasurement(let measurement):
            // Re-add the measurement that was deleted
            myEntities.reAddMeasurement(measurement)
            
        case .placedAngle(let angle):
            // Remove the angle that was placed
            angle.container.removeFromParent()
            myEntities.removeAngleFromStorage(angle)
            
        case .deletedAngle(let angle):
            // Re-add the angle that was deleted
            myEntities.reAddAngle(angle)
        }
    }
    
    /// Clear all undo history
    func clearAll() {
        actions.removeAll()
    }
}

