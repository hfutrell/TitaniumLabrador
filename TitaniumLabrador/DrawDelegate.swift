//
//  ViewDelegate.swift
//  TitaniumLabrador
//
//  Created by Holmes Futrell on 11/12/20.
//

import MetalKit

class DrawDelegate: NSObject {
    
    lazy var metalContext: TLMetalContext = {
       return TLMetalContext()
    }()
    
    func draw<A: TLContext>(in context: A) {
        context.concatenate(self.transform)
        context.drawDebugTriangle()
        context.translateBy(x: 5, y: 5)
        context.rotate(by: 0.2)
        context.drawDebugTriangle()

    }
    var transform: CGAffineTransform {
      //  return CGAffineTransform.init(scaleX: 2, y: 2)
        return CGAffineTransform.init(translationX: 50, y: 50).scaledBy(x: 4, y: 4)
    }
}

extension DrawDelegate: MTKViewDelegate {
    func draw(in view: MTKView) {
        let context = self.metalContext
        context.view = view
        self.draw(in: context)
        context.flush()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }
}
