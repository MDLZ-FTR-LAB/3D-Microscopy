import SwiftUI
import RealityKitContent

@main
struct _D_MicroscopyApp: App {

    @StateObject private var appModel = AppModel()
    @StateObject private var actionUndoManager = ActionUndoManager()

    var body: some Scene {

        // Main screen launch (import / show model controls)
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environmentObject(appModel)
                .environmentObject(actionUndoManager)
        }
        .windowStyle(.plain)
        
        // Open mixed reality view (no full immersion)
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(appModel)
                .environmentObject(actionUndoManager)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    print("Immersive appeared. isOn: \(appModel.isOn), modelURL: \(String(describing: appModel.modelURL))")
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        // Gesture toolbar
        WindowGroup(id: "GestureControlPanel") {
            GestureToolbar()
                .environmentObject(appModel)
                .environmentObject(actionUndoManager)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1200, height: 100)
        // In front, toward the bottom of the user's field of view
        .defaultWindowPlacement { content, context in
            if let mainWindow = context.windows.first(where: { $0.id == "MainWindow" }) {
                return WindowPlacement(.below(mainWindow))
            }
            return WindowPlacement()
        }
        // Measurement and angle tutorial
        WindowGroup(id: "TutorialView", for: TutorialType.self) { $type in
            if let type {
                TutorialView(type: type)
            }
        }
    }
}
