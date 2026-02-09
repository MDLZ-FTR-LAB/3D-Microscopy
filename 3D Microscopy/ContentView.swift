//
//  ContentView.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Immersive Microscopy Viewer")
                .font(.largeTitle)
                .bold()

            Text("🌌 Clicking 'Show Model' enters you into immersive view.\n🪐 Clicking 'Hide Model' returns you to mixed reality view.")
            Button("Import Model File") {
                showImporter = true
            }
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)

            // This button toggles you into the immersive space above
            ToggleImmersiveSpaceButton()
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)

            List(appModel.availableModels, id: \.self) { modelURL in
                Button(modelURL.lastPathComponent) {
                    appModel.modelURL = modelURL
                }
            }
            .frame(height: 200)
        }
        .fileImporter(
            isPresented: $showImporter,
            //only importing .obj for now
            allowedContentTypes: [UTType(filenameExtension: "obj")!],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

                    guard gotAccess else {
                        print("Could not access file due to restrictions.")
                        return
                    }
                    copyToDocuments(originalURL: url)
                }
                loadAvailableModels()
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
        .onAppear {
            loadAvailableModels()
        }
    }

//helper funcyions for loading models
    
    private func loadAvailableModels() {
        let docsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        do {
            let files = try FileManager.default
                .contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)
            appModel.availableModels = files
                .filter { $0.pathExtension.lowercased() == "obj" }
        } catch {
            print("Failed to load models: \(error)")
        }
    }

    private func copyToDocuments(originalURL: URL) {
        let docsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        let destURL = docsURL.appendingPathComponent(originalURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: originalURL, to: destURL)
            print("copied")
        } catch {
            print("Copy failed: \(error)")
        }
    }
}
