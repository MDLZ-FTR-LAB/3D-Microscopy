
//
//  FileImportButton.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//
/*
import SwiftUI
import UniformTypeIdentifiers

struct FileImportButton: View {
    var onPick: (URL) -> Void

    var body: some View {
        Button("Import 3D Model (.obj + .mtl)") {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = PickerDelegate(onPick: onPick)

            // Present manually using the topmost view controller
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.keyWindow?.rootViewController {
                root.present(picker, animated: true)
            }
        }
    }

    class PickerDelegate: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}
*/
