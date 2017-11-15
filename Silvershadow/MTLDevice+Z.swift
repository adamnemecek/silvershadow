//
//  MTLDevice+Z.swift
//  Silvershadow
//
//  Created by Kaz Yoshikawa on 1/10/17.
//  Copyright © 2017 Electricwoods LLC. All rights reserved.
//

import Foundation
import MetalKit

extension MTLDevice {

	var textureLoader: MTKTextureLoader {
		return MTKTextureLoader(device: self)
	}

    func makeDefaultSamplerState() -> MTLSamplerState {
        return makeSamplerState(descriptor: .`default`)!
    }

	func texture(of image: CGImage) -> MTLTexture? {

		let textureUsage : MTLTextureUsage = [.pixelFormatView, .shaderRead]
        var options: [MTKTextureLoader.Option : Any] = [.SRGB: false as NSNumber,
                                                        .textureUsage: textureUsage.rawValue as NSNumber]
		if #available(iOS 10.0, *) {
			options[.origin] = true as NSNumber
		}

		guard let texture = try? textureLoader.newTexture(cgImage: image, options: options) else { return nil }

		if texture.pixelFormat == .bgra8Unorm { return texture }
		return texture.makeTextureView(pixelFormat: .bgra8Unorm)
	}

	func texture(of image: XImage) -> MTLTexture? {
        return image.cgImage.flatMap { self.texture(of: $0) }
	}

	func texture(named name: String) -> MTLTexture? {
        var options : [MTKTextureLoader.Option: Any] = [.SRGB : false as NSNumber]

		if #available(iOS 10.0, *) {
			options[.origin] = MTKTextureLoader.Origin.topLeft as NSObject
		}

		do { return try textureLoader.newTexture(name: name, scaleFactor: 1.0,
                                                 bundle: nil,
                                                 options: options) }
		catch { fatalError("\(error)") }
	}

	#if os(iOS)
	func makeHeap(size: Int) -> MTLHeap {
		let descriptor = MTLHeapDescriptor()
		descriptor.storageMode = .shared
		descriptor.size = size
		return self.makeHeap(descriptor: descriptor)
	}
	#endif
}
