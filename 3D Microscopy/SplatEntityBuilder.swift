
/*
  SplatEntityBuilder.swift
  3D Microscopy

  Assembles a RealityKit Entity from GaussianSplatBuffers.
*/

import Foundation
import RealityKit

// MARK: - Shared types

struct GaussianSplatBuffers: @unchecked Sendable {
    let splatCount: UInt64
    let degreeSH: UInt8
    let tupleSH: UInt8

    let positionBuffer: LowLevelBuffer?
    let scaleBuffer: LowLevelBuffer?
    let rotationBuffer: LowLevelBuffer?
    let opacityBuffer: LowLevelBuffer?
    let shBuffer: LowLevelBuffer?
}

enum GaussianSplatError: Error {
    case invalidData(String)
}

// MARK: - Entity construction

#if targetEnvironment(simulator)

@MainActor
func makeSplatEntity(from _: GaussianSplatBuffers, isLinear: Bool = false) throws -> Entity {
    throw GaussianSplatError.invalidData("Gaussian Splat rendering requires running on device")
}

#else

import Metal

// MARK: - Descriptor builders

func makeDescriptor(
    buffer: LowLevelBuffer,
    format: MTLAttributeFormat,
    stride: Int
) -> GaussianSplatResource.BufferDescriptor {
    GaussianSplatResource.BufferDescriptor(buffer: buffer, format: format, stride: stride, offset: 0)
}

func makeSHDescriptor(
    buffer: LowLevelBuffer,
    tupleSH: UInt8
) -> GaussianSplatResource.BufferDescriptor {
    makeDescriptor(buffer: buffer, format: .float3, stride: 3 * 4 * Int(tupleSH + 1))
}

@MainActor
func assembleSplatComponent(from buffers: GaussianSplatBuffers, isLinear: Bool = false) throws -> GaussianSplatComponent {
    guard let pos = buffers.positionBuffer,
          let scale = buffers.scaleBuffer,
          let rotation = buffers.rotationBuffer,
          let opacity = buffers.opacityBuffer,
          let shBuf = buffers.shBuffer else {
        throw GaussianSplatError.invalidData("One or more GPU buffers failed to allocate")
    }

    let degree = GaussianSplatResource.SphericalHarmonicDegree(rawValue: buffers.degreeSH) ?? .zero
    let bufferResource = try GaussianSplatResource.BufferResource(
        count: Int(buffers.splatCount),
        position: makeDescriptor(buffer: pos, format: .float3, stride: 3 * 4),
        scale: makeDescriptor(buffer: scale, format: .float3, stride: 3 * 4),
        rotation: makeDescriptor(buffer: rotation, format: .float4, stride: 4 * 4),
        opacity: makeDescriptor(buffer: opacity, format: .float, stride: 1 * 4),
        sphericalHarmonics: (makeSHDescriptor(buffer: shBuf, tupleSH: buffers.tupleSH), degree)
    )

    let splatResource = GaussianSplatResource(bufferResource)
    if isLinear {
        splatResource.scaleActivation   = .identity
        splatResource.opacityActivation = .identity
    } else {
        splatResource.scaleActivation   = .exponential
        splatResource.opacityActivation = .sigmoid
    }
    return GaussianSplatComponent(splatResource)
}

@MainActor
func makeSplatEntity(from buffers: GaussianSplatBuffers, isLinear: Bool = false) throws -> Entity {
    let comp = try assembleSplatComponent(from: buffers, isLinear: isLinear)
    let entity = Entity()
    entity.components.set(comp)
    return entity
}

#endif

