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
    @State private var measureTutorialShown = false
    @State private var angleTutorialShown = false
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(GestureMode.allCases, id: \.self) { mode in
                Button {
                    
                    appModel.modeSwitchTime = Date()
                    appModel.gestureMode = mode

                    
                    let wasOn = appModel.isOn
                    appModel.isOn = (mode == .measure || mode == .angle)
                    
                    if mode == .measure && !measureTutorialShown {
                        openWindow(id: "TutorialView", value: TutorialType.measure)
                        measureTutorialShown = true
                    }

                    if mode == .angle && !angleTutorialShown {
                        openWindow(id: "TutorialView", value: TutorialType.angle)
                        angleTutorialShown = true
                    }
                    
                    if !appModel.isOn && wasOn {
                        appModel.myEntities.fingerTips[.left]?.position = SIMD3<Float>(-1000, -1000, -1000)
                        appModel.myEntities.fingerTips[.right]?.position = SIMD3<Float>(-1000, -1000, -1000)
                    }
                
                    
                } label: {
                    HStack {
                        switch mode {
                        case .none:
                            Image(systemName: "hand.raised.slash")
                        case .drag:
                            Image(systemName: "hand.tap")
                        case .rotate:
                            Image(systemName: "arrow.clockwise")
                        case .scale:
                            Image(systemName: "plus.magnifyingglass")
                        case .measure:
                            Image(systemName: "ruler")
                        case .angle:
                            Image(systemName: "angle")
                        }
                        
                        Text(mode.rawValue.capitalized)
                            .fixedSize()
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
