//
//  AnnotationInputView.swift
//  3D Microscopy
//
//  Created by Future Lab on 7/29/25.
//  Text input interface for annotation editing

import SwiftUI

struct AnnotationInputView: View {
    @ObservedObject var annotationManager: AnnotationManager
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var tempText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Edit Annotation")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("✕") {
                    annotationManager.cancelEditing()
                    dismissWindow(id: "AnnotationInput")
                }
                .font(.title2)
                .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Text Input Area
            VStack(alignment: .leading, spacing: 8) {
                Text("Note Text:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $tempText)
                    .focused($isTextFieldFocused)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                
                Text("\(tempText.count)/200 characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // Quick Actions
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Quick Insert:")
//                    .font(.headline)
//                    .foregroundColor(.secondary)
//                
//                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
//                    ForEach(quickInsertOptions, id: \.text) { option in
//                        Button(action: {
//                            insertQuickText(option.text)
//                        }) {
//                            VStack(spacing: 4) {
//                                Text(option.emoji)
//                                    .font(.title2)
//                                Text(option.text)
//                                    .font(.caption2)
//                                    .multilineTextAlignment(.center)
//                            }
//                            .frame(height: 60)
//                            .frame(maxWidth: .infinity)
//                            .background(Color(.systemGray5))
//                            .cornerRadius(8)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                    }
//                }
//            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    appModel.cancelPendingAnnotation()
                    dismissWindow(id: "AnnotationInput")
                }
                .foregroundColor(.red)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(20)
                
                Spacer()
                
                Button("Clear") {
                    tempText = ""
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
                
                Button("Save") {
                    appModel.createAnnotationWithText(tempText)
                    dismissWindow(id: "AnnotationInput")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.purple)
                .cornerRadius(20)
                .disabled(tempText.count > 200)
            }
        }
        .padding(24)
        .frame(width: 450, height: 500)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 30)
        .onAppear {
            tempText = ""
            isTextFieldFocused = true
        }
        .onChange(of: tempText) { _, newValue in
            // Limit character count
            if newValue.count > 200 {
                tempText = String(newValue.prefix(200))
            }
        }
    }
    
    private func insertQuickText(_ text: String) {
        if tempText.isEmpty {
            tempText = text
        } else {
            tempText += " " + text
        }
    }
    
//    private var quickInsertOptions: [(emoji: String, text: String)] {
//        [
//            ("🔍", "Important"),
//            ("⚠️", "Warning"),
//            ("💡", "Idea"),
//            ("📏", "Measure"),
//            ("🎯", "Focus here"),
//            ("❓", "Question"),
//            ("✅", "Verified"),
//            ("🧪", "Sample"),
//            ("📊", "Data point")
//        ]
//    }
}

// MARK: - Annotation Controls View
struct AnnotationControlsView: View {
    @ObservedObject var annotationManager: AnnotationManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Annotation Mode")
                .font(.caption.bold())
                .foregroundColor(.white)
            
            Text(annotationManager.getAnnotationSummary())
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            if annotationManager.annotationCount > 0 {
                HStack(spacing: 8) {
                    Button("Clear All") {
                        annotationManager.clearAllAnnotations()
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    
                    Button("Remove Last") {
                        annotationManager.removeLastAnnotation()
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
//        .background(Color.purple.opacity(0.8))
        .background(Color.purple)
        .cornerRadius(12)
        .frame(maxWidth: 200)
    }
}

#Preview {
    AnnotationControlsView(annotationManager: AnnotationManager())
}
