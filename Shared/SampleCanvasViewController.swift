//
//	ViewController.swift
//	SilvershadowApp
//
//	Created by Kaz Yoshikawa on 12/25/16.
//	Copyright © 2016 Electricwoods LLC. All rights reserved.
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif


class SampleCanvasViewController: XViewController {

	var sampleScene: SampleCanvas!

	@IBOutlet var renderView: RenderView!

	override func viewDidLoad() {
		super.viewDidLoad()

		let contentSize = CGSize(2048, 1024)

		self.sampleScene = SampleCanvas(device: renderView.device, contentSize: contentSize)
		self.renderView.scene = self.sampleScene
	}

	#if os(macOS)
	override var representedObject: Any? {
		didSet {
		}
	}
	#endif

}

