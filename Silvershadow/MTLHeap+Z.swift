//
//  File.swift
//  Silvershadow
//
//  Created by Kaz Yoshikawa on 2/28/17.
//  Copyright © 2017 Electricwoods LLC. All rights reserved.
//

import Foundation
import MetalKit

#if os(iOS)
extension MTLHeap {

	func makeBuffer(bytes pointer: UnsafeRawPointer, length: Int, options: MTLResourceOptions = [.storageModeShared]) -> MTLBuffer {
		let buffer = makeBuffer(length: length, options: options)
		let destinationArrayPtr = UnsafeMutableRawPointer(OpaquePointer(buffer.contents()))
		destinationArrayPtr.copyBytes(from: pointer, count: length)
		return buffer
	}

}
#endif
