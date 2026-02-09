//
//  GestureToolbar.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

import SwiftUI

struct GestureToolbar: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var numMeasured = 0
    @State private var numAnnotated = 0
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(GestureMode.allCases, id: \.self) { mode in
                Button {
                    appModel.gestureMode = mode
                    
                    // Clean up crop preview when switching modes
                    if mode != .crop {
                        appModel.cleanupCropPreview()
                        appModel.isDrawingCropLine = false
                        appModel.cropStartPoint = nil
                        appModel.cropEndPoint = nil
                    }
                    
                    
                    //if presses measure enables hand tracking
                    let wasOn = appModel.isOn
                    appModel.isOn = (mode == .measure || mode == .annotate)
                    
                    if(mode == .measure && numMeasured == 0) {
                        openWindow(id:"TutorialView")
                        numMeasured += 1
                    }
                    
                    if(mode == .annotate && numAnnotated == 0) {
                        openWindow(id:"AnnotationTutorialView")
                        numAnnotated += 1
                    }
                    
                    // reset finger positions
                    if !appModel.isOn && wasOn {
                        appModel.myEntities.fingerTips[.left]?.position = SIMD3<Float>(-1000, -1000, -1000)
                        appModel.myEntities.fingerTips[.right]?.position = SIMD3<Float>(-1000, -1000, -1000)
                    }
                } label: {
                    HStack {
                        //icons
                        switch mode {
                        case .none:
                            Image(systemName: "hand.raised.slash")
                        case .drag:
                            Image(systemName: "hand.tap")
                        case .rotate:
                            Image(systemName: "arrow.clockwise")
                        case .scale:
                            Image(systemName: "plus.magnifyingglass") //icons for every gesture
                        case .measure:
                            Image(systemName: "ruler")
                        case .annotate:
                            Image(systemName: "note.text")
                        case .crop:
                            Image(systemName: "scissors")
                        }
                        
                        Text(mode.rawValue.capitalized)
                            .fixedSize() // prevents wrapping
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(appModel.gestureMode == mode ? Color.purple.opacity(0.8) : Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}
