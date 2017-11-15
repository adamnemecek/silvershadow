//
//	RenderView.swift
//	Silvershadow
//
//	Created by Kaz Yoshikawa on 12/12/16.
//	Copyright © 2016 Electricwoods LLC. All rights reserved.
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

import MetalKit
import GLKit

class RenderView: XView, MTKViewDelegate {

	var scene: Scene? {
		didSet {
            guard scene !== oldValue else { return }
            if let scene = scene {
                self.mtkView.device = scene.device
                self.commandQueue = scene.device.makeCommandQueue()
                scene.didMove(to: self)
            }
            self.setNeedsLayout() // implies adjusting document
		}
	}

	private (set) lazy var mtkView: MTKView = {
		let mtkView = MTKView(frame: self.bounds)
		mtkView.device = MTLCreateSystemDefaultDevice()!
		mtkView.colorPixelFormat = .`default`
		mtkView.delegate = self
		self.addSubviewToFit(mtkView)
		mtkView.enableSetNeedsDisplay = true
//		mtkView.isPaused = true
		return mtkView
	}()

	#if os(iOS)
	private (set) lazy var scrollView: UIScrollView = {
		let scrollView = UIScrollView(frame: self.bounds)
		scrollView.delegate = self
		scrollView.backgroundColor = .clear
		scrollView.maximumZoomScale = 4.0
		scrollView.minimumZoomScale = 1.0
		scrollView.autoresizesSubviews = false
		scrollView.delaysContentTouches = false
		scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
		self.addSubviewToFit(scrollView)
		scrollView.addSubview(self.contentView)
		self.contentView.frame = self.bounds
		return scrollView
	}()

    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        self.mtkView.setNeedsDisplay()
        self.drawView.setNeedsDisplay()
    }

    var minimumNumberOfTouchesToScroll: Int {
        get { return self.scrollView.panGestureRecognizer.minimumNumberOfTouches }
        set { self.scrollView.panGestureRecognizer.minimumNumberOfTouches = newValue }
    }

    var scrollEnabled: Bool {
        get { return self.scrollView.isScrollEnabled }
        set { self.scrollView.isScrollEnabled = newValue }
    }

    var delaysContentTouches: Bool {
        get { return self.scrollView.delaysContentTouches }
        set { self.scrollView.delaysContentTouches = newValue }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.sendSubview(toBack: self.mtkView)
        self.bringSubview(toFront: self.drawView)
        self.bringSubview(toFront: self.scrollView)

        if let scene = self.scene {
            let contentSize = scene.contentSize
            self.scrollView.contentSize = contentSize
            //            self.contentView.bounds = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
            let bounds = CGRect(size: contentSize)
            let frame = self.scrollView.convert(bounds, to: self.contentView)
            self.contentView.frame = frame
        }
        else {
            self.scrollView.contentSize = self.bounds.size
            self.contentView.bounds = self.bounds
        }
        self.scrollView.autoresizesSubviews = false;
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.autoresizingMask = []
        self.contentView.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        self.setNeedsDisplay()
    }

	#elseif os(macOS)
	private (set) lazy var scrollView: NSScrollView = {
		let scrollView = NSScrollView(frame: self.bounds)
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = true
		scrollView.borderType = .noBorder
		scrollView.drawsBackground = false
//		scrollView.autoresingMask = [.flexibleWidth, .flexibleHeight]
		self.addSubviewToFit(scrollView)

		// isFlipped cannot be set, then replace clipView with subclass it does
		let clipView = FlippedClipView(frame: self.contentView.frame)
		clipView.drawsBackground = false
		clipView.backgroundColor = .clear

		scrollView.contentView = clipView // scrollView's contentView is NSClipView
		scrollView.documentView = self.contentView
		scrollView.contentView.postsBoundsChangedNotifications = true

		// posting notification when zoomed, scrolled or resized

		NotificationCenter.default.addObserver(self, selector: #selector(scrollContentDidChange),
					name: NSView.boundsDidChangeNotification, object: nil)
		scrollView.allowsMagnification = true
		scrollView.maxMagnification = 4
		scrollView.minMagnification = 1

		return scrollView
	}()


	var lastCall = Date()

	@objc func scrollContentDidChange(_ notification: Notification) {
		Swift.print("since lastCall = \(-lastCall.timeIntervalSinceNow * 1000) ms")
		self.lastCall = Date()
//		self.drawView.setNeedsDisplay()
		self.mtkView.setNeedsDisplay()
	}

    override func setNeedsDisplay() {
        self.mtkView.setNeedsDisplay()
        self.drawView.setNeedsDisplay()
    }

    override var isFlipped: Bool {
        return true
    }

    override func layout() {
        super.layout()

        self.sendSubview(toBack: self.mtkView)
        self.bringSubview(toFront: self.drawView)
        self.bringSubview(toFront: self.scrollView)

        let contentSize = scene?.contentSize ?? bounds.size

        self.scrollView.documentView?.frame = CGRect(size: contentSize)

        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.autoresizingMask = [.maxXMargin, /*.viewMinYMargin,*/ .maxYMargin]
        self.setNeedsDisplay()
    }
	#endif

	private (set) lazy var drawView: RenderDrawView = {
		let drawView = RenderDrawView(frame: self.bounds)
		drawView.backgroundColor = .clear
		drawView.renderView = self
		self.addSubviewToFit(drawView)
		return drawView
	}()

	private (set) lazy var contentView: RenderContentView = {
		let renderableContentView = RenderContentView(frame: self.bounds)
		renderableContentView.renderView = self
		renderableContentView.backgroundColor = .clear
		renderableContentView.translatesAutoresizingMaskIntoConstraints = false
		#if os(iOS)
		renderableContentView.isUserInteractionEnabled = true
		#endif
		return renderableContentView
	}()

	var device: MTLDevice {
		return self.mtkView.device!
	}

	private (set) var commandQueue: MTLCommandQueue?

	// MARK: -

	let semaphore = DispatchSemaphore(value: 1)

	func draw(in view: MTKView) {

		let date = Date()
		defer { Swift.print("RenderView: draw() ", -date.timeIntervalSinceNow * 1000, " ms") }

		self.semaphore.wait()
		defer { self.semaphore.signal() }

		self.drawView.setNeedsDisplay()

		guard let drawable = self.mtkView.currentDrawable,
            let renderPassDescriptor = self.mtkView.currentRenderPassDescriptor,
            let scene = self.scene,
            let commandQueue = self.commandQueue else { return }

        let rgba = self.scene?.backgroundColor.rgba ?? XRGBA(r: 0.9, g: 0.9, b: 0.9, a: 1.0)

		renderPassDescriptor.colorAttachments[0].texture = drawable.texture // error on simulator target
        renderPassDescriptor.colorAttachments[0].clearColor = .init(color: rgba)
		renderPassDescriptor.colorAttachments[0].loadAction = .clear
		renderPassDescriptor.colorAttachments[0].storeAction = .store

		// just for clearing screen
		do {
			let commandBuffer = commandQueue.makeCommandBuffer()!
			let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
			commandEncoder.endEncoding()
			commandBuffer.commit()
		}

		// setup render context
		let transform = GLKMatrix4(self.drawingTransform)
		renderPassDescriptor.colorAttachments[0].loadAction = .load
		let renderContext = RenderContext(renderPassDescriptor: renderPassDescriptor,
                                          commandQueue: commandQueue,
                                          contentSize: scene.contentSize,
                                          deviceSize: self.mtkView.drawableSize,
                                          transform: transform,
                                          zoomScale: self.zoomScale)

		// actual rendering
		scene.render(in: renderContext)

		do {
			let commandBuffer = commandQueue.makeCommandBuffer()!
			commandBuffer.present(drawable)
			commandBuffer.commit()
		}
	}

	var zoomScale: CGFloat {
		return scrollView.zoomScale
	}

	var drawingTransform: CGAffineTransform {
		guard let scene = self.scene else { return .identity }
		let targetRect = contentView.convert(self.contentView.bounds, to: self.mtkView)

		let transform1 = scene.bounds.transform(to: targetRect)
		let transform2 = self.mtkView.bounds.transform(to: CGRect(x: -1.0, y: -1.0, width: 2.0, height: 2.0))

		#if os(iOS)
        let transform3 = CGAffineTransform.identity.translatedBy(x: 0, y: +1).scaledBy(x: 1, y: -1).translatedBy(x: 0, y: 1)
		let transform = transform1 * transform2 * transform3
		#elseif os(macOS)
        let transform0 = CGAffineTransform(translationX: 0, y: self.contentView.bounds.height).scaledBy(x: 1, y: -1)
		let transform = transform0 * transform1 * transform2
		#endif
		return transform
	}

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
	}
}

#if os(iOS)
extension RenderView: UIScrollViewDelegate {

	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return self.contentView
	}

	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		self.setNeedsDisplay()
	}

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		self.setNeedsDisplay()
	}

}
#endif

#if os(macOS)
class FlippedClipView: NSClipView {

	override var isFlipped: Bool { return true }

}
#endif
