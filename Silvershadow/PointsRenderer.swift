//
//	PointsRenderer.swift
//	Silvershadow
//
//	Created by Kaz Yoshikawa on 1/11/16.
//	Copyright © 2016 Electricwoods LLC. All rights reserved.
//

import Foundation
import CoreGraphics
import Metal
import QuartzCore
import GLKit

typealias PointVertex = PointsRenderer.Vertex

extension MTLSamplerDescriptor {

    convenience init(min: MTLSamplerMinMagFilter,
                     max: MTLSamplerMinMagFilter,
                     s: MTLSamplerAddressMode,
                     t: MTLSamplerAddressMode) {
        self.init()
        minFilter = min
        magFilter = max
        sAddressMode = s
        tAddressMode = t
    }

    static let `default` = MTLSamplerDescriptor(min: .nearest,
                                                max: .linear,
                                                s: .repeat,
                                                t: .repeat)
}

//
//	PointsRenderer
//

class PointsRenderer: Renderer {

    typealias Vertex = CGPath.Vertex

    // TODO: needs refactoring

    struct Uniforms {
        var transform: GLKMatrix4
        var zoomScale: Float
        var unused2: Float = 0
        var unused3: Float = 0
        var unused4: Float = 0

        init(transform: GLKMatrix4, zoomScale: Float) {
            self.transform = transform
            self.zoomScale = zoomScale
        }
    }

    let device: MTLDevice


    // MARK: -

    required init(device: MTLDevice) {
        self.device = device
    }

    var library: MTLLibrary {
        return self.device.newDefaultLibrary()!
    }

    var vertexDescriptor: MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].offset = MemoryLayout<float2>.size
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.size

        return vertexDescriptor
    }

    lazy var renderPipelineState: MTLRenderPipelineState = {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = self.vertexDescriptor
        renderPipelineDescriptor.vertexFunction = self.library.makeFunction(name: "points_vertex")!
        renderPipelineDescriptor.fragmentFunction = self.library.makeFunction(name: "points_fragment")!

        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .`default`
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

        // I don't believe this but this is what it is...
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try! self.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }()

    lazy var colorSamplerState: MTLSamplerState = {
        return self.device.makeSamplerState(descriptor: .`default`)
    }()

    func vertexBuffer(for vertices: [Vertex], capacity: Int? = nil) -> VertexBuffer<Vertex> {
        return VertexBuffer(device: device, vertices: vertices, capacity: capacity)
    }

    func render(context: RenderContext, texture: MTLTexture, vertexBuffer: VertexBuffer<Vertex>) {
        let transform = context.transform
        var uniforms = Uniforms(transform: transform, zoomScale: Float(context.zoomScale))
        let uniformsBuffer = device.makeBuffer(bytes: &uniforms, length: MemoryLayout<Uniforms>.size, options: [])

        let commandBuffer = context.makeCommandBuffer()
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: context.renderPassDescriptor)
        encoder.setRenderPipelineState(renderPipelineState)

        encoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, at: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, at: 1)

        encoder.setFragmentTexture(texture, at: 0)
        encoder.setFragmentSamplerState(colorSamplerState, at: 0)

        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertexBuffer.count)
        encoder.endEncoding()
        commandBuffer.commit()
    }

    func render(context: RenderContext, texture: MTLTexture, vertexes: [Vertex]) {
        let vertexBuffer = self.vertexBuffer(for: vertexes)
        self.render(context: context, texture: texture, vertexBuffer: vertexBuffer)
    }

    func render(context: RenderContext, texture: MTLTexture, points: [Point], width: Float) {
        var vertexes = [Vertex]()
        points.pair { (p1, p2) in
            vertexes += self.vertexes(from: p1, to: p2, width: width)
        }
        self.render(context: context, texture: texture, vertexes: vertexes)
    }

    func vertexes(from: Point, to: Point, width: Float) -> [Vertex] {
        let vector = (to - from)
        let numberOfPoints = Int(ceil(vector.length / 2))
        let step = vector / Float(numberOfPoints)
        return (0 ..< numberOfPoints).map {
            Vertex(from + step * Float($0), width)
        }
    }

}


extension RenderContext {

    func render(vertexes: [PointVertex], texture: MTLTexture) {
        let renderer: PointsRenderer = self.device.renderer()
        let vertexBuffer = renderer.vertexBuffer(for: vertexes)
        renderer.render(context: self, texture: texture, vertexBuffer: vertexBuffer)
    }

    func render(points: [Point], texture: MTLTexture, width: Float) {
        let renderer: PointsRenderer = self.device.renderer()
        renderer.render(context: self, texture: texture, points: points, width: width)
    }
    
}

