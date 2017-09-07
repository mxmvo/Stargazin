//
//  Renderer.swift
//  StarGazing
//
//  Created by Maxim Oldenbeek on 07/04/2017.
//  Copyright © 2017 Maxim Oldenbeek. All rights reserved.
//


import Metal
import simd
import MetalKit
import GLKit


@objc
class Renderer : NSObject
{
  weak var view: MTKView!
  
  let device: MTLDevice
  let sampler: MTLSamplerState
  var bufferProvider: BufferProvider

  
  init?(mtkView: MTKView) {
    
    view = mtkView
    device = view.device!
    
    self.bufferProvider = BufferProvider(device: device, inflightBuffersCount: 3)
    sampler = Renderer.buildSamplerStateWithDevice(device, addressMode: .repeat, filter: .linear)
    
    super.init()
  }
  
  
  class func buildSamplerStateWithDevice(_ device: MTLDevice,
                                         addressMode: MTLSamplerAddressMode,
                                         filter: MTLSamplerMinMagFilter) -> MTLSamplerState
  {
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.sAddressMode = addressMode
    samplerDescriptor.tAddressMode = addressMode
    samplerDescriptor.minFilter = filter
    samplerDescriptor.magFilter = filter
    return device.makeSamplerState(descriptor: samplerDescriptor)
  }

  
  func render(_ view: MTKView, commandQueue: MTLCommandQueue, projectionMatrix: GLKMatrix4, worldModelMatrix: GLKMatrix4,objects: [object]) {
   
    // Our command buffer is a container for the work we want to perform with the GPU.
    let commandBuffer = commandQueue.makeCommandBuffer()
    let renderPassDescriptor = view.currentRenderPassDescriptor
    var i = 0
    // Ask the view for a configured render pass descriptor. It will have a loadAction of
    // MTLLoadActionClear and have the clear color of the drawable set to our desired clear color.
    for object in objects{
      
      if let renderPassDescriptor = renderPassDescriptor {
        // If drawing the first object clear the screen. Otherwise previous frames stay put
        if i == 0 {
          renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        } else {
         renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        }
        
        // Create a render encoder to clear the screen and draw our objects
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderEncoder.pushDebugGroup("Draw sphere")
      
        // Set the pipeline state so the GPU knows which vertex and fragment function to invoke.
        renderEncoder.setRenderPipelineState(object.pipeLine)
      
        // Bind the buffer containing the array of vertex structures so we can read it in our vertex shader.
        renderEncoder.setVertexBuffer(object.vertexBuffer, offset:0, at:0)
      
        // Bind our texture so we can sample from it in the fragment shader
        renderEncoder.setFragmentTexture(object.texture, at: 0)
      
        // Bind our sampler state so we can use it to sample the texture in the fragment shader
        renderEncoder.setFragmentSamplerState(sampler, at: 0)
      
        let uniformBuffer = bufferProvider.nextUniformsBuffer(projectionMatrix, modelViewMatrix: worldModelMatrix)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, at: 1)
        
      
        // Issue the draw call to draw the indexed geometry of the mesh
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: object.model.count/5 )
        renderEncoder.popDebugGroup()
        // We are finished with this render command encoder, so end it.
        renderEncoder.endEncoding()
      
        // Tell the system to present the cleared drawable to the screen.
        i += 1
      }
  }
    
    if let drawable = view.currentDrawable
    {
      commandBuffer.present(drawable)
    }
    // Now that we're done issuing commands, we commit our buffer so the GPU can get to work.
    commandBuffer.commit()
  }
  

}
