
//
//  UndoManager.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

import SwiftUI
import RealityKit

enum UndoAction {
    case transformChanged(entity: Entity, previousTransform: Transform)
    case measurementPlaced
    case anglePlaced
}

@MainActor
class ActionUndoManager: ObservableObject {
    @Published private(set) var actions: [UndoAction] = []

    var canUndo: Bool { !actions.isEmpty }

    func push(_ action: UndoAction) {
        actions.append(action)
    }

    func undo(myEntities: MyEntities) {
        guard let action = actions.popLast() else { return }
        switch action {
        case .transformChanged(let entity, let previousTransform):
            entity.transform = previousTransform
        case .measurementPlaced:
            myEntities.removeLastMeasurement()
        case .anglePlaced:
            myEntities.removeLastAngle()
        }
    }

    func clearAll() {
        actions.removeAll()
    }
}

