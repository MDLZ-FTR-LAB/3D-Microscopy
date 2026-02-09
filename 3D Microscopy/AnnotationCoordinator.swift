//
//  AnnotationCoordinator.swift
//  3D Microscopy
//
//  Created by Future Lab on 7/29/25.
//  Coordinates annotation creation workflow

import SwiftUI

struct AnnotationCoordinator: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var annotationText: String = ""
    @State private var showingInput = false
    
    var body: some View {
        VStack {
            if appModel.pendingAnnotationPosition != nil {
                VStack(spacing: 20) {
                    Text("Create Annotation")
                        .font(.title2.bold())
                    
                    TextField("Enter annotation text...", text: $annotationText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            appModel.cancelPendingAnnotation()
                            dismissWindow(id: "AnnotationInput")
                        }
                        .foregroundColor(.red)
                        
                        Button("Create") {
                            appModel.createAnnotationWithText(annotationText)
                            annotationText = ""
                            dismissWindow(id: "AnnotationInput")
                        }
                        .foregroundColor(.blue)
                        .disabled(annotationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            }
        }
        .frame(width: 300, height: 200)
    }
}
