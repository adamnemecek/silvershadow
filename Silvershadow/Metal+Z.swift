//
//  Metal+Z.swift
//  Silvershadow
//
//  Created by Adam Nemecek on 6/8/17.
//  Copyright © 2017 Electricwoods LLC. All rights reserved.
//

import MetalKit

extension MTLPixelFormat {
    static let `default` : MTLPixelFormat = .bgra8Unorm
}

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
