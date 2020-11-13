//
//  TLContext.swift
//  TitaniumLabrador
//
//  Created by Holmes Futrell on 11/13/20.
//

import Foundation
import UIKit
import MetalKit

let points = [CGPoint(x: 100, y: 0), CGPoint(x: 0, y: 75), CGPoint(x: 200, y: 100)]

let programSource = """

    using namespace metal;

    struct VertexOutput {
        float4 position [[position]];
        float4 color;
    };

    vertex VertexOutput hello_vertex(
                        const device float2 *pos_data [[ buffer(0) ]],
                        const device float4 *color_data [[ buffer(1) ]],
                        const device float3x2 *matrix [[ buffer(2) ]],
                        unsigned int v_id [[vertex_id]],
                        unsigned int instance_id [[instance_id]])
    {
        VertexOutput vOut;
        float3x2 mat = matrix[instance_id];
        float2 result = (float2x2(mat[0], mat[1]) * pos_data[v_id].xy) + mat[2];
        vOut.position = float4(result.x, result.y, 0, 1);
        vOut.color = color_data[v_id];
        return vOut;
    }

    fragment float4 hello_fragment(VertexOutput in [[stage_in]]) {
        return in.color;
    }
"""

protocol TLContext {
    var ctm: CGAffineTransform { get }
    func rotate(by: CGFloat)
    func scaleBy(x: CGFloat, y: CGFloat)
    func translateBy(x: CGFloat, y: CGFloat)
    func concatenate(_ transform: CGAffineTransform)
    func saveGState()
    func restoreGState()
    func setFillColor(_ color: CGColor)
    func flush()
    
    func drawDebugTriangle()
}

extension CGContext: TLContext {
    func drawDebugTriangle() {
        addLines(between: points)
        closePath()
        strokePath()
    }
}

extension CGAffineTransform {
    var formattedForMetal: [Float] {
        return [Float(a), Float(b), Float(c), Float(d), Float(tx), Float(ty)]
    }
}

extension Collection where Element == CGPoint {
    var formattedForMetal: [Float] {
        self.flatMap { [Float($0.x), Float($0.y)] }
    }
}

class TLMetalContext {
    
    private struct StackEntry {
        var ctm: CGAffineTransform = .identity
        var fillColor: [Float] = [0, 0, 0, 1]
    }
    private struct Instance {
        var transform: CGAffineTransform
        var fillColor: [Float]
    }
    weak var view: MTKView? = nil
    private var instances: [Instance] = []
    private var stack: [StackEntry] = [StackEntry()]
    private func resetState() {
        instances = []
        stack = [StackEntry()]
    }
    init() {
        self.resetState()
    }
    private func renderMetalCommands() {
        guard let view = self.view else {
            assertionFailure("no view")
            return
        }
        
        guard let device = view.device else {
            assertionFailure("no metal device set for rendering")
            return
        }
        
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: programSource, options: nil)
        } catch let error as NSError {
            assertionFailure("library creation failed with error \(error)")
            return
        } catch {
            assertionFailure("library creation failed")
            return
        }
            
        let vertexFunction = library.makeFunction(name: "hello_vertex")
        let fragmentFunction = library.makeFunction(name: "hello_fragment")
    
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            assertionFailure("could not get render pass descriptor")
            return
        }
        guard let commandQueue = device.makeCommandQueue() else {
            assertionFailure("command queue creation failed")
            return
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            assertionFailure("command buffer creation failed.")
            return
        }

//        renderPassDescriptor.colorAttachments[0].texture = currentTexture
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0,1.0,1.0,1.0)

        guard let renderEncoder: MTLRenderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            assertionFailure("creation of render encoder failed.")
            return
        }

        let posData: [Float] = points.formattedForMetal
        
        let colData: [Float] = [
            1.0, 0.0, 0.0, 1.0,
            0.0, 1.0, 0.0, 1.0,
            0.0, 0.0, 1.0, 1.0,
        ]
                        
        let matrixData: [Float] = self.instances.flatMap {
            $0.transform.formattedForMetal
        }

        let positionBuffer = posData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: [])
        }
                
        let colorBuffer = colData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: [])
        }
        
        let matrixBuffer = matrixData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: [])
        }

        renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(matrixBuffer, offset: 0, index: 2)
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        let renderPipelineState: MTLRenderPipelineState
            
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            assertionFailure("make render pipeline state failed with error")
            return
        }
            
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: self.instances.count)
        renderEncoder.endEncoding()
                
        guard let currentDrawable = view.currentDrawable else {
            assertionFailure("could nto get drawable")
            return
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

extension TLMetalContext: TLContext {
    
    func drawDebugTriangle() {
        guard let view = self.view else {
            assertionFailure("view is not set to get view transform")
            return
        }
        let viewTransform = CGAffineTransform(translationX: -1, y: 1).scaledBy(x: 2.0 / view.bounds.size.width, y: -2.0 / view.bounds.size.height)
        let fillColor = stack[stack.count-1].fillColor
        let instance = Instance(transform: self.ctm.concatenating(viewTransform), fillColor: fillColor)
        instances.append(instance)
    }
    
    func flush() {
        self.renderMetalCommands()
        self.resetState()
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
            
}
