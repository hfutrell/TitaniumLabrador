//
//  TLView.swift
//  TitaniumLabrador
//
//  Created by Holmes Futrell on 11/12/20.
//

import Foundation
import MetalKit

class TLView: MTKView {
    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.isPaused = true
        self.enableSetNeedsDisplay = true
        self.contentMode = .redraw
        
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
    }
    
    static let programSource = """

        struct VertexOutput {
            float4 position [[position]];
            float4 color;
        };

        vertex VertexOutput hello_vertex(
                            const device float4 *pos_data [[ buffer(0) ]],
                            const device float4 *color_data [[ buffer(1) ]],
                            unsigned int v_id [[vertex_id]])
        {
            VertexOutput vOut;
            vOut.position = pos_data[v_id];
            vOut.color = color_data[v_id];
            return vOut;
        }
    
        fragment float4 hello_fragment(VertexOutput in [[stage_in]]) {
            return in.color;
        }
    """
    
    override func draw(_ rect: CGRect) {
                
        guard let renderPassDescriptor = self.currentRenderPassDescriptor else {
            assertionFailure("could not get render pass descriptor")
            return
        }
        guard let device = self.device else {
            assertionFailure("no metal device set for rendering")
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

        let posData: [Float] = [
            0.0, 0.33, 0.0, 1.0,
            -0.33, -0.33, 0.0, 1.0,
            0.33, -0.33, 0.0, 1.0,
        ]
        let colData: [Float] = [
            1.0, 0.0, 0.0, 1.0,
            0.0, 1.0, 0.0, 1.0,
            0.0, 0.0, 1.0, 1.0,
        ]
        
        let positionBuffer = posData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: [])
        }
                
        let colorBuffer = colData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            device.makeBuffer(bytes: buffer.baseAddress!, length: buffer.count, options: [])
        }
        
        renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 1)
         
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: TLView.programSource, options: nil)
        } catch let error as NSError {
            assertionFailure("library creation failed with error \(error)")
            return
        } catch {
            assertionFailure("library creation failed")
            return
        }
            
        let vertexFunction = library.makeFunction(name: "hello_vertex")
        let fragmentFunction = library.makeFunction(name: "hello_fragment")
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat

        let renderPipelineState: MTLRenderPipelineState
            
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            assertionFailure("make render pipeline state failed with error")
            return
        }
            
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
        
        guard let currentDrawable = self.currentDrawable else {
            assertionFailure("could nto get drawable")
            return
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
