//
//	SolidRenderer.swift
//	Silvershadow
//
//	Created by Kaz Yoshikawa on 11/12/16.
//	Copyright © 2016 Electricwoods LLC. All rights reserved.
//

import Foundation
import MetalKit
import GLKit


typealias ColorVertex = ColorRenderer.Vertex


extension Rect {
    typealias Vertex = ColorRenderer.Vertex

    func vertices(color: XColor) -> [Vertex] {
        let l = minX, r = maxX, t = minY, b = maxY
        let rgba = color.rgba
        let (_r, _g, _b, _a) = (Float(rgba.r), Float(rgba.g), Float(rgba.b), Float(rgba.a))
        return [
            Vertex(x: l, y: t, z: 0, w: 1, r: _r, g: _g, b: _b, a: _a),
            Vertex(x: l, y: b, z: 0, w: 1, r: _r, g: _g, b: _b, a: _a),
            Vertex(x: r, y: b, z: 0, w: 1, r: _r, g: _g, b: _b, a: _a),
            Vertex(x: l, y: t, z: 0, w: 1, r: _r, g: _g, b: _b, a: _a),
            Vertex(x: r, y: b, z: 0, w: 1, r: _r, g: _g, b: _b, a: _a),
            Vertex(x: r, y: t, z: 0, w: 1, r: _r, g: _g, b: _b, a: _a),
        ]
    }
}

class ColorRenderer: Renderer {

	typealias VertexType = Vertex

	// MARK: -

	var device: MTLDevice

	// MARK: -

	required init(device: MTLDevice) {
		self.device = device
	}
	
	deinit {
	}

	struct Vertex {
		var x, y, z, w, r, g, b, a: Float
	}

	struct Uniforms {
		var transform: GLKMatrix4
	}

	var vertexDescriptor: MTLVertexDescriptor {
		let vertexDescriptor = MTLVertexDescriptor()
		vertexDescriptor.attributes[0].offset = 0
		vertexDescriptor.attributes[0].format = .float2
		vertexDescriptor.attributes[0].bufferIndex = 0

		vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 4
		vertexDescriptor.attributes[1].format = .float4
		vertexDescriptor.attributes[1].bufferIndex = 0
		
		vertexDescriptor.layouts[0].stepFunction = .perVertex
		vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.size
		return vertexDescriptor
	}

	lazy var library: MTLLibrary = {
		return self.device.newDefaultLibrary()!
	}()

	lazy var renderPipelineState: MTLRenderPipelineState = {
		let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
		renderPipelineDescriptor.vertexDescriptor = self.vertexDescriptor
		renderPipelineDescriptor.vertexFunction = self.library.makeFunction(name: "color_vertex")!
		renderPipelineDescriptor.fragmentFunction = self.library.makeFunction(name: "color_fragment")!

		renderPipelineDescriptor.colorAttachments[0].pixelFormat = .`default`
		renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
		renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

		renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
		renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
		renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		
		let renderPipelineState = try! self.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
		return renderPipelineState
	}()

	lazy var colorSamplerState: MTLSamplerState = {
		return self.device.makeSamplerState()
	}()

	func render(context: RenderContext, vertexBuffer: VertexBuffer<Vertex>) {
		var uniforms = Uniforms(transform: context.transform)
		let uniformsBuffer = device.makeBuffer(bytes: &uniforms, length: MemoryLayout<Uniforms>.size, options: [])

		let commandBuffer = context.makeCommandBuffer()

		let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: context.renderPassDescriptor)
		encoder.setRenderPipelineState(renderPipelineState)
		encoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, at: 0)
		encoder.setVertexBuffer(uniformsBuffer, offset: 0, at: 1)
		
		encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexBuffer.count)

		encoder.endEncoding()

		commandBuffer.commit()
	}

	func render(context: RenderContext, rect: Rect, color: XColor) {
		let vertices = rect.vertices(color: color)
        let vertexBuffer = VertexBuffer(device: device, vertices: vertices)
		render(context: context, vertexBuffer: vertexBuffer)
	}

}


extension RenderContext {


	func render(triangles: [(ColorVertex, ColorVertex, ColorVertex)]) {
		
		let renderer: ColorRenderer = self.device.renderer()
		let vertices: [ColorVertex] = triangles.flatMap { [$0.0, $0.1, $0.2] }
        let vertexBuffer = VertexBuffer(device: device, vertices: vertices)

        renderer.render(context: self, vertexBuffer: vertexBuffer)
	}

	func render(triangles: [(Point, Point, Point)], color: XColor) {
		let rgba = color.rgba
		let (r, g, b, a) = (Float(rgba.r), Float(rgba.g), Float(rgba.b), Float(rgba.a))
		let renderer: ColorRenderer = self.device.renderer()
		let vertices: [ColorVertex] = triangles.flatMap {
			[$0.0, $0.1, $0.2].map { ColorVertex(x: $0.x, y: $0.y, z: 0, w: 1, r: r, g: g, b: b, a: a) }
		}
        let vertexBuffer = VertexBuffer(device: device, vertices: vertices)
        renderer.render(context: self, vertexBuffer: vertexBuffer)
	}

}
