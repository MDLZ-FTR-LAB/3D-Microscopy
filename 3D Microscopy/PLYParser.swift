
/*
  PLYParser.swift
  3D Microscopy

  Parses binary PLY files and deinterleaves splat data into per-field GPU buffers.
*/

import Foundation
import RealityKit

// MARK: - PLY Data Structures

nonisolated struct PLYProperty {
    var index = 0
    var stride = 0
}

nonisolated struct GaussianSplatData {
    let data: Data
    let splatCount: UInt64
    let degreeSH: UInt8
    let tupleSH: UInt8
    let lineStride: Int

    let position, scale, rotation, opacity: PLYProperty
    let diffuseColor: PLYProperty
    let sphericalHarmonics: PLYProperty
}

// MARK: - Header parsing

private nonisolated struct PLYHeader {
    var vertexCount: UInt64 = 0
    var binaryStart: Int = 0
    var propertyCount: Int = 0
    var numSHCoeffs: UInt8 = 0
    var position = PLYProperty()
    var scale = PLYProperty()
    var rotation = PLYProperty()
    var diffuseColor = PLYProperty()
    var sphericalHarmonics = PLYProperty()
    var opacity = PLYProperty()
    var inVertexElement = false

    struct ElementInfo {
        let name: String
        let count: UInt64
        var byteSize: Int = 0
    }
    var elements: [ElementInfo] = []
}

nonisolated extension PLYHeader {
    mutating func processLine(_ line: String, endingAt idx: Int) throws -> Bool {
        if line.hasPrefix("element ") {
            let parts = line.components(separatedBy: .whitespaces)
            if parts.count >= 3, let count = UInt64(parts[2]) {
                let name = parts[1]
                elements.append(ElementInfo(name: name, count: count))
                inVertexElement = (name == "vertex")
                if inVertexElement { vertexCount = count }
            }
        } else if line == "end_header" {
            binaryStart = idx + 1
            return true
        } else if line.hasPrefix("property") {
            try processProperty(line)
        }
        return false
    }

    private mutating func processProperty(_ line: String) throws {
        let parts = line.components(separatedBy: .whitespaces)
        let typeName = parts[1]
        let typeSize = propertyTypeSize(typeName)
        guard typeSize > 0 else {
            throw GaussianSplatError.invalidData("Unsupported property type in PLY: \(typeName)")
        }

        if !elements.isEmpty {
            elements[elements.count - 1].byteSize += typeSize
        }

        guard inVertexElement, typeName == "float" else { return }

        let name = parts[2]
        assignVertexField(named: name)
        if name.hasPrefix("f_rest") { numSHCoeffs += 1 }
        propertyCount += 1
    }

    private mutating func assignVertexField(named name: String) {
        switch name {
        case "x":        position           = PLYProperty(index: propertyCount, stride: 3)
        case "f_dc_0":   diffuseColor       = PLYProperty(index: propertyCount, stride: 3)
        case "opacity":  opacity            = PLYProperty(index: propertyCount, stride: 1)
        case "rot_0":    rotation           = PLYProperty(index: propertyCount, stride: 4)
        case "scale_0":  scale              = PLYProperty(index: propertyCount, stride: 3)
        case "f_rest_0": sphericalHarmonics = PLYProperty(index: propertyCount, stride: 3)
        default: break
        }
    }

    private func propertyTypeSize(_ typeName: String) -> Int {
        switch typeName {
        case "float", "int", "uint":    return 4
        case "uchar":                    return 1
        case "double", "int64":          return 8
        case "short", "ushort":          return 2
        default:                         return 0
        }
    }
}

// MARK: - File loading

nonisolated func readGaussianSplatFile(_ url: URL) throws -> GaussianSplatData {
    let fileData = try Data(contentsOf: url)
    let header = try parseHeader(from: fileData)

    guard header.binaryStart > 0 else {
        throw GaussianSplatError.invalidData("Missing end_header in PLY file")
    }
    guard header.vertexCount > 0 else {
        throw GaussianSplatError.invalidData("No vertices found in PLY file")
    }
    guard let vertexElementIndex = header.elements.firstIndex(where: { $0.name == "vertex" }) else {
        throw GaussianSplatError.invalidData("No vertex element found in PLY file")
    }

    var vertexDataOffset = 0
    for index in 0..<vertexElementIndex {
        vertexDataOffset += header.elements[index].byteSize * Int(header.elements[index].count)
    }

    let vertexByteCount = 4 * header.propertyCount * Int(header.vertexCount)
    let vertexStart = header.binaryStart + vertexDataOffset
    let vertexEnd = vertexStart + vertexByteCount
    guard vertexEnd <= fileData.count else {
        throw GaussianSplatError.invalidData(
            "Expected at least \(vertexByteCount) bytes, got \(fileData.count - vertexStart)"
        )
    }
    let binary = fileData.subdata(in: vertexStart..<vertexEnd)

    let tupleSH = UInt8(Float(header.numSHCoeffs) / 3)
    let degreeSH = UInt8(sqrt(Float(tupleSH + 1)) - 1)
    var shProp = header.sphericalHarmonics
    shProp.stride *= Int(tupleSH + 1)
    if shProp.stride < 3 {
        shProp.stride = 3
    }

    return GaussianSplatData(
        data: binary,
        splatCount: header.vertexCount,
        degreeSH: degreeSH,
        tupleSH: tupleSH,
        lineStride: header.propertyCount,
        position: header.position,
        scale: header.scale,
        rotation: header.rotation,
        opacity: header.opacity,
        diffuseColor: header.diffuseColor,
        sphericalHarmonics: shProp
    )
}

private nonisolated func parseHeader(from fileData: Data) throws -> PLYHeader {
    var header = PLYHeader()
    var line = ""
    for (idx, byte) in fileData.enumerated() {
        if byte == 0xA {
            if try header.processLine(line, endingAt: idx) { break }
            line = ""
        } else {
            line.append(Character(Unicode.Scalar(byte)))
        }
    }
    return header
}

// MARK: - Deinterleaving

private nonisolated func copyPLYField(
    _ prop: PLYProperty,
    from floats: UnsafeBufferPointer<Float>,
    into buffer: LowLevelBuffer?,
    count: Int,
    lineStride: Int
) {
    buffer?.withUnsafeMutableBytes { dst in
        let out = dst.bindMemory(to: Float.self)
        var srcOff = prop.index
        var dstOff = 0
        for _ in 0..<count {
            for floatIdx in 0..<prop.stride {
                out[dstOff + floatIdx] = floats[srcOff + floatIdx]
            }
            srcOff += lineStride
            dstOff += prop.stride
        }
    }
}

private nonisolated func fillSHBuffer(_ buffer: LowLevelBuffer?, from splatData: GaussianSplatData) {
    buffer?.withUnsafeMutableBytes { dst in
        splatData.data.withUnsafeBytes { src in
            let floats = src.bindMemory(to: Float.self)
            let out = dst.bindMemory(to: Float.self)
            let count = Int(splatData.splatCount)
            var dstOff = 0
            for splatIdx in 0..<count {
                let dcBase = splatData.diffuseColor.index + splatIdx * splatData.lineStride
                out[dstOff] = floats[dcBase]
                out[dstOff + 1] = floats[dcBase + 1]
                out[dstOff + 2] = floats[dcBase + 2]
                dstOff += 3
                guard splatData.tupleSH > 0 else { continue }
                let shBase = splatData.sphericalHarmonics.index + splatIdx * splatData.lineStride
                for tuple in 0..<Int(splatData.tupleSH) {
                    for channel in 0..<3 {
                        out[dstOff] = floats[shBase + channel * Int(splatData.tupleSH) + tuple]
                        dstOff += 1
                    }
                }
            }
        }
    }
}

nonisolated func deinterleaveGaussianSplatData(_ splatData: GaussianSplatData) throws -> GaussianSplatBuffers {
    let count = Int(splatData.splatCount)
    func aligned(_ prop: PLYProperty) -> Int { (count * prop.stride * 4 + 15) & ~0xF }

    let positionBuffer = try? LowLevelBuffer(descriptor: .init(capacity: aligned(splatData.position), sizeMultiple: 16))
    let scaleBuffer = try? LowLevelBuffer(descriptor: .init(capacity: aligned(splatData.scale), sizeMultiple: 16))
    let rotationBuffer = try? LowLevelBuffer(descriptor: .init(capacity: aligned(splatData.rotation), sizeMultiple: 16))
    let opacityBuffer = try? LowLevelBuffer(descriptor: .init(capacity: aligned(splatData.opacity), sizeMultiple: 16))
    let shBuffer = try? LowLevelBuffer(descriptor: .init(capacity: aligned(splatData.sphericalHarmonics), sizeMultiple: 16))

    splatData.data.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
        let floats = src.bindMemory(to: Float.self)
        copyPLYField(splatData.position, from: floats, into: positionBuffer, count: count, lineStride: splatData.lineStride)
        copyPLYField(splatData.scale, from: floats, into: scaleBuffer, count: count, lineStride: splatData.lineStride)
        copyPLYField(splatData.rotation, from: floats, into: rotationBuffer, count: count, lineStride: splatData.lineStride)
        copyPLYField(splatData.opacity, from: floats, into: opacityBuffer, count: count, lineStride: splatData.lineStride)
    }

    fillSHBuffer(shBuffer, from: splatData)

    return GaussianSplatBuffers(
        splatCount: splatData.splatCount,
        degreeSH: splatData.degreeSH,
        tupleSH: splatData.tupleSH,
        positionBuffer: positionBuffer,
        scaleBuffer: scaleBuffer,
        rotationBuffer: rotationBuffer,
        opacityBuffer: opacityBuffer,
        shBuffer: shBuffer
    )
}

