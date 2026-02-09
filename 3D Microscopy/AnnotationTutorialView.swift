//
//  AnnotationTutorialView.swift
//  3D Microscopy
//
//  Created by Future Lab on 7/29/25.
//


import SwiftUI

struct AnnotationTutorialView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("How to Annotate")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundColor(.primary)
                .padding(.top)
            
            Divider()
                .padding(.horizontal, 24)
            
            HStack(alignment: .top, spacing: 10) {
                Text("Point at your model and pinch to create sticky notes")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.yellow)
                        .imageScale(.large)
                    Text("Add a sticky note")
                        .font(.title3.bold())
                    Spacer()
                    Text("🤏 Left Pinch")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                
                HStack {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.orange)
                        .imageScale(.large)
                    Text("Remove last note")
                        .font(.title3.bold())
                    Spacer()
                    Text("🤌 Right Pinch")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                    Text("Edit note text")
                        .font(.title3.bold())
                    Spacer()
                    Text("👆 Tap note")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                
                // Features Note
                Divider()
                    .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .imageScale(.medium)
                        Text("Sticky notes always face you and include:")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Custom text up to 200 characters")
                        //Text("• Quick insert buttons for common phrases")
                        Text("• Multiple color options")
                        Text("• Automatic positioning and sizing")
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.leading, 30)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Dismiss Button
            Button(action: {
                dismissWindow(id: "AnnotationTutorialView")
            }) {
                Text("Got it 📝")
                    .font(.headline)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 500, height: 600)
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .shadow(radius: 30)
        .glassBackgroundEffect()
    }
}

#Preview {
    AnnotationTutorialView()
}
