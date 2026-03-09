import SwiftUI
import RealityKitContent
// import RealityKit   // Uncomment after structure compiles, and only if your target supports it.

@main
struct _D_MicroscopyApp: App {

    @StateObject private var appModel = AppModel()

    var body: some Scene {

        // Main screen launch
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environmentObject(appModel)
        }
        .windowStyle(.plain)
        
        // Open mixed reality view (no full immersion)
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    print("Immersive appeared. isOn: \(appModel.isOn), modelURL: \(String(describing: appModel.modelURL))")
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed) // changed `full` to `mixed`
        
        // Gesture toolbar
        WindowGroup(id: "GestureControlPanel") {
            GestureToolbar()
                .environmentObject(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1200, height: 100)

        // Measurement and angle tutorial
        WindowGroup(id: "TutorialView", for: TutorialType.self) { $type in
            if let type {
                TutorialView(type: type)
            }
        }
    }
}
