//
//  ViewDelegate.swift
//  TitaniumLabrador
//
//  Created by Holmes Futrell on 11/12/20.
//

import MetalKit

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

class DrawDelegate: NSObject {
    
}

/*
 
 Normalized device coordinates use a left-handed coordinate system (see Figure 1) and map to positions in the viewport. These coordinates are independent of viewport size. The lower-left corner of the viewport is at an (x,y) coordinate of (-1.0,-1.0) and the upper corner is at (1.0,1.0)
 
 */


extension DrawDelegate: CoreGraphicsViewDelegate {
    func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        
        context?.concatenate(self.transform)
        
        context?.setStrokeColor(UIColor.black.cgColor)
        context?.setLineWidth(2)
        
        context?.addLines(between: points)
        context?.closePath()
        context?.strokePath()
    }
    
    var transform: CGAffineTransform {
      //  return CGAffineTransform.init(scaleX: 2, y: 2)
        return CGAffineTransform.init(translationX: 50, y: 50).scaledBy(x: 4, y: 4)
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

let points = [CGPoint(x: 100, y: 0), CGPoint(x: 0, y: 75), CGPoint(x: 200, y: 100)]

extension DrawDelegate: MTKViewDelegate {
        
    func draw(in view: MTKView) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            assertionFailure("could not get render pass descriptor")
            return
        }
        guard let device = view.device else {
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

        let posData: [Float] = points.formattedForMetal
        
        let colData: [Float] = [
            1.0, 0.0, 0.0, 1.0,
            0.0, 1.0, 0.0, 1.0,
            0.0, 0.0, 1.0, 1.0,
        ]
        
        let viewTransform = CGAffineTransform(translationX: -1, y: 1).scaledBy(x: 2.0 / view.bounds.size.width, y: -2.0 / view.bounds.size.height)
        
        let finalTransform = self.transform.concatenating(viewTransform)
        
        let matrixData: [Float] = finalTransform.formattedForMetal

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
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
        
        guard let currentDrawable = view.currentDrawable else {
            assertionFailure("could nto get drawable")
            return
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()

    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }

}
