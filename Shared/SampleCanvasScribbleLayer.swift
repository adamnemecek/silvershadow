//
//	SampleCanvasLayer2.swift
//	Silvershadow
//
//	Created by Kaz Yoshikawa on 12/29/16.
//	Copyright © 2016 Electricwoods LLC. All rights reserved.
//

import Foundation
import MetalKit
import GLKit


class SampleCanvasScribbleLayer: CanvasLayer {

	lazy var brushSapeTexture: MTLTexture? = {
		return self.device?.texture(of: XImage(named: "Particle")!)!
	}()


	lazy var brushPatternTexture: MTLTexture! = {
		return self.device?.texture(of: XImage(named: "Pencil")!)!
	}()

	lazy var strokePaths: [CGPath] = {
		return []
	}()

	override func render(context: RenderContext) {
        guard let bezierRenderer : BezierRenderer = (device.map { $0.renderer() }) else { return }

		context.brushPattern = self.brushPatternTexture
		bezierRenderer.render(context: context, cgPaths: strokePaths)
	}

}

