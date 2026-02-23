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
        
        // Open immersive
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
        .immersionStyle(selection: .constant(.mixed), in: .mixed) // Isabella - changed `full` to `mixed` for video
        
        // Gesture toolbar
        WindowGroup(id: "GestureControlPanel") {
            GestureToolbar()
                .environmentObject(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1200, height: 100)

        // Measurement tutorial
        WindowGroup(id: "TutorialView") {
            TutorialView()
                .environmentObject(appModel)
        }
    }
}
