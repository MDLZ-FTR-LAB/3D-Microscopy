
//
//  ShowModelButton.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//

import SwiftUI

struct ShowModelButton: View {

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Button {
            Task { @MainActor in
                switch appModel.immersiveSpaceState {
                    case .open:
                        appModel.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()
                        dismissWindow(id: "GestureControlPanel")

                    case .closed:
                        appModel.immersiveSpaceState = .inTransition
                        switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                            case .opened:
                                print("opened immersive")
                                openWindow(id: "GestureControlPanel")
                                break

                            case .userCancelled, .error:
                                fallthrough
                            @unknown default:
                                appModel.immersiveSpaceState = .closed
                        }

                    case .inTransition:
                        break
                }
            }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Hide Model" : "Show Model")
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}

