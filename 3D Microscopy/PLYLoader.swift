
/*
  PLYLoader.swift
  3D Microscopy

  Loads a Gaussian Splat PLY file from the app bundle and builds a RealityKit Entity.
*/

import Foundation
import RealityKit

// MARK: - Bundle URL

/// Returns the URL for `<assetName>.ply` in the main bundle, or throws if the resource is missing.
private func bundlePLYURL(assetName: String) throws -> URL {
    guard let url = Bundle.main.url(forResource: assetName, withExtension: "ply") else {
        throw GaussianSplatError.invalidData("\(assetName).ply not found in app bundle")
    }
    return url
}

// MARK: - Public API

/// Loads the splat from the main bundle and returns a RealityKit Entity
/// configured with a GaussianSplatComponent for Gaussian Splat rendering.
@MainActor
func loadPLYEntity(assetName: String) async throws -> Entity {
    let url = try bundlePLYURL(assetName: assetName)
    let buffers = try await Task.detached(priority: .userInitiated) {
        let splatData = try readGaussianSplatFile(url)
        return try deinterleaveGaussianSplatData(splatData)
    }.value
    return try makeSplatEntity(from: buffers)
}

