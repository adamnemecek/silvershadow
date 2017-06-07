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
            if scene !== oldValue {
                if let scene = scene {
                    self.mtkView.device = scene.device
                    self.commandQueue = scene.device.makeCommandQueue()
                    scene.didMove(to: self)
                }
                self.setNeedsLayout() // implies adjusting document
            }
        }
    }

    #if os(iOS)
    override func layoutSubviews() {
        super.layoutSubviews()

        sendSubview(toBack: mtkView)
        bringSubview(toFront: drawView)
        bringSubview(toFront: scrollView)

        if let scene = self.scene {
            let contentSize = scene.contentSize
            self.scrollView.contentSize = contentSize
            //			self.contentView.bounds = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
            let bounds = CGRect(origin: .zero, size: contentSize)
            let frame = scrollView.convert(bounds, to: contentView)
            contentView.frame = frame
        }
        else {
            scrollView.contentSize = bounds.size
            contentView.bounds = bounds
        }
        scrollView.autoresizesSubviews = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        setNeedsDisplay()
    }

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
    #endif

    #if os(macOS)
    override func layout() {
        super.layout()

        sendSubview(toBack: mtkView)
        bringSubview(toFront: drawView)
        bringSubview(toFront: scrollView)

        let size = scene?.contentSize ?? bounds.size
        scrollView.documentView?.frame = CGRect(origin: .zero, size: size)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.autoresizingMask = [.viewMaxXMargin, /*.viewMinYMargin,*/ .viewMaxYMargin]
        setNeedsDisplay()
    }

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
                                               name: .NSViewBoundsDidChange, object: nil)
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

    #endif

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
        return mtkView.device!
    }

    private (set) var commandQueue: MTLCommandQueue?

    // MARK: -

    #if os(iOS)
    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        self.mtkView.setNeedsDisplay()
        self.drawView.setNeedsDisplay()
    }
    #elseif os(macOS)
    override func setNeedsDisplay() {
        self.mtkView.setNeedsDisplay()
        self.drawView.setNeedsDisplay()
    }

    override var isFlipped: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    #endif

    // MARK: -

    let semaphore = DispatchSemaphore(value: 1)

    func draw(in view: MTKView) {

        let date = Date()
        defer { Swift.print("RenderView: draw() ", -date.timeIntervalSinceNow * 1000, " ms") }

        self.semaphore.wait()
        defer { self.semaphore.signal() }

        self.drawView.setNeedsDisplay()

        guard let drawable = mtkView.currentDrawable,
            let renderPassDescriptor = self.mtkView.currentRenderPassDescriptor,
            let scene = self.scene,
            let commandQueue = self.commandQueue else { return }


        let rgba = self.scene?.backgroundColor.rgba ?? XRGBA(0.9, 0.9, 0.9, 1.0)
        let clearColor = MTLClearColorMake(Double(rgba.r), Double(rgba.g), Double(rgba.b), Double(rgba.a))
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture // error on simulator target
        renderPassDescriptor.colorAttachments[0].clearColor = clearColor
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        // just for clearing screen
        do {
            let commandBuffer = commandQueue.makeCommandBuffer()
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            commandEncoder.endEncoding()
            commandBuffer.commit()
        }

        // setup render context
        let transform = GLKMatrix4(self.drawingTransform)
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        let renderContext = RenderContext(
            renderPassDescriptor: renderPassDescriptor, commandQueue: commandQueue,
            contentSize: scene.contentSize, deviceSize: self.mtkView.drawableSize,
            transform: transform, zoomScale: self.zoomScale)

        // actual rendering
        scene.render(in: renderContext)

        do {
            let commandBuffer = commandQueue.makeCommandBuffer()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    var zoomScale: CGFloat {
        return scrollView.zoomScale
    }

    var drawingTransform: CGAffineTransform {
        guard let scene = self.scene else { return .identity }
        let targetRect = contentView.convert(contentView.bounds, to: mtkView)
        let transform0 = CGAffineTransform(translationX: 0, y: contentView.bounds.height).scaledBy(x: 1, y: -1)
        let transform1 = scene.bounds.transform(to: targetRect)
        let transform2 = mtkView.bounds.transform(to: CGRect(x: -1.0, y: -1.0, width: 2.0, height: 2.0))
        let transform3 = CGAffineTransform.identity.translatedBy(x: 0, y: +1).scaledBy(x: 1, y: -1).translatedBy(x: 0, y: 1)
        #if os(iOS)
            let transform = transform1 * transform2 * transform3
        #elseif os(macOS)
            let transform = transform0 * transform1 * transform2
        #endif
        return transform
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    // MARK: -

    #if os(iOS)
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
    #endif
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
