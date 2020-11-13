//
//  ViewController.swift
//  TitaniumLabrador
//
//  Created by Holmes Futrell on 11/12/20.
//

import MetalKit
import UIKit

class CoreGraphicsView: UIView {
    weak var delegate: DrawDelegate?
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            assertionFailure("could not get context")
            return
        }
        self.delegate?.draw(in: context)
    }
}

class ViewController: UIViewController {

    let drawDelegate = DrawDelegate()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let frame = view.frame
        let autoresizeMask: UIView.AutoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let metalView = MTKView()
        metalView.delegate = drawDelegate
        metalView.frame = frame
        metalView.autoresizingMask = autoresizeMask
        
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true
        metalView.contentMode = .redraw
        let device = MTLCreateSystemDefaultDevice()
        metalView.device = device

        
        self.view.addSubview(metalView)
     
        let coreGraphicsView = CoreGraphicsView()
        coreGraphicsView.frame = frame
        coreGraphicsView.delegate = drawDelegate
        coreGraphicsView.isOpaque = false
        coreGraphicsView.autoresizingMask = autoresizeMask
        coreGraphicsView.contentMode = .redraw
        coreGraphicsView.alpha = 0.5
        self.view.addSubview(coreGraphicsView)
    }
}

