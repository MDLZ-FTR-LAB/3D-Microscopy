
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

            Text("\n📥 Tapping the 'Import Model File' button loads a new model to the list below.\n🍪 Clicking 'Show Model' displays the scanned model in your space, Mixed Reality (MR) style.\n📦 Please select the scanned model from the list below to load it before clicking 'Show Model'.")
            Button("Import Model File") {
                showImporter = true
            }
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)

            ShowModelButton()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)

            List(appModel.availableModels, id: \.self) { modelURL in
                Button(modelURL.lastPathComponent) {
                    let ext = modelURL.pathExtension.lowercased()
                    if ext == "ply" {
                        appModel.splatURL = modelURL
                        appModel.modelURL = nil
                    } else {
                        appModel.modelURL = modelURL
                        appModel.splatURL = nil
                    }
                }
                .foregroundColor(isSelected(modelURL) ? .green : .primary)
            }
            .frame(height: 200)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "obj")!,
                UTType(filenameExtension: "usdz")!,
                UTType(filenameExtension: "ply")!
            ],
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

    // MARK: - Helpers

    private func isSelected(_ url: URL) -> Bool {
        url == appModel.modelURL || url == appModel.splatURL
    }

    private func loadAvailableModels() {
        let docsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        do {
            let files = try FileManager.default
                .contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)
            let supportedExtensions = ["obj", "usdz", "ply"]
            appModel.availableModels = files
                .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
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
            print("✅ Copied \(originalURL.lastPathComponent) to Documents")
        } catch {
            print("Copy failed: \(error)")
        }
    }
}

