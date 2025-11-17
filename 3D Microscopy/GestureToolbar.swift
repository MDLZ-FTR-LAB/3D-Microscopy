//
//  GestureToolbar.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

import SwiftUI

struct GestureToolbar: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 16) {
            ForEach(GestureMode.allCases, id: \.self) { mode in
                Button {
                    appModel.gestureMode = mode
                    //if presses measure enables hand tracking
                    let wasOn = appModel.isOn
<<<<<<< Updated upstream
                    appModel.isOn = (mode == .measure)
=======
                    appModel.isOn = (mode == .measure || mode == .annotate || mode == .angle)
>>>>>>> Stashed changes
                    
                    
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
                            Image(systemName: "plus.magnifyingglass")
                        case .measure:
                            Image(systemName: "ruler")
<<<<<<< Updated upstream
=======
                        case .angle:
                            Image(systemName: "arrow.triangle.2.circlepath")
                        case .annotate:
                            Image(systemName: "note.text")
>>>>>>> Stashed changes
                        case .crop:
                            Image(systemName: "scissor")
                        }
                        
                        Text(mode.rawValue.capitalized)
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
