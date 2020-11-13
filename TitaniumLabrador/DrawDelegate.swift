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
        let rect = CGRect(x: 0, y: 0, width: 20, height: 30)
        
        context.concatenate(self.transform)
        
        context.setFillColor(UIColor.red.cgColor)
        context.addRect(rect)
        context.fillPath(using: .evenOdd)

        context.translateBy(x: 5, y: 5)
        context.rotate(by: 0.2)
        
        context.setFillColor(UIColor.orange.cgColor)
        context.addRect(rect)
        context.fillPath(using: .evenOdd)

        context.translateBy(x: 5, y: 5)
        context.rotate(by: 0.2)
        
        context.setFillColor(UIColor.blue.cgColor)
        context.addRect(rect)
        context.fillPath(using: .evenOdd)
    }
    
    var transform: CGAffineTransform {
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
