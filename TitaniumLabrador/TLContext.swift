//
//  TLContext.swift
//  TitaniumLabrador
//
//  Created by Holmes Futrell on 11/13/20.
//

import Foundation

protocol TLContext {
    var ctm: CGAffineTransform { get }
    func rotate(by: CGFloat)
    func scaleBy(x: CGFloat, y: CGFloat)
    func translateBy(x: CGFloat, y: CGFloat)
    func concatenate(_ transform: CGAffineTransform)
    func saveGState()
    func restoreGState()
    func setFillColor(_ color: CGColor)
    
    func drawDebugTriangle()
}

extension CGContext: TLContext {
    func drawDebugTriangle() {
        
    }
}

class TLMetalContext: TLContext {
    
    func drawDebugTriangle() {
        
    }
    
    func rotate(by amount: CGFloat) {
        ctm = ctm.rotated(by: amount)
    }
    
    func scaleBy(x: CGFloat, y: CGFloat) {
        ctm = ctm.scaledBy(x: x, y: y)
    }
    
    func translateBy(x: CGFloat, y: CGFloat) {
        ctm = stack.last!.ctm.translatedBy(x: x, y: y)
    }
    
    func concatenate(_ transform: CGAffineTransform) {
        ctm = ctm.concatenating(transform)
    }
    
    func saveGState() {
        stack.append(stack.last!)
    }
    
    func restoreGState() {
        stack.removeLast()
    }

    private struct State {
        var ctm: CGAffineTransform = .identity
        var fillColor: [Float] = [0, 0, 0, 1]
    }
    
    private var stack: [State] = [State()]
    
    private(set) var ctm: CGAffineTransform {
        get {
            return stack.last!.ctm
        }
        set {
            stack[stack.count-1].ctm = newValue
        }
    }
    
    func setFillColor(_ color: CGColor) {
        guard let components = color.components else {
            assertionFailure("could not get color components.")
            return
        }
        var rgba: [Float] = [0.0, 0.0, 0.0, 1.0]
        if components.count > 0 {
            rgba[0] = Float(components[0])
        }
        if components.count > 1 {
            rgba[1] = Float(components[1])
        }
        if components.count > 2 {
            rgba[2] = Float(components[2])
        }
        if components.count > 3 {
            rgba[3] = Float(components[3])
        }
        stack[stack.count-1].fillColor = rgba
    }
        
    init() {
        
    }
}
