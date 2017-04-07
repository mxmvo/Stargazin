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
  let renderPipelineState: MTLRenderPipelineState
  let sampler: MTLSamplerState
  let textureSky: MTLTexture
  let textureCoord: MTLTexture
  let arrSky: [Float]
  let arrCoord: [Float]
  var vertexBufferSky: MTLBuffer
  var vertexBufferCoord: MTLBuffer
  var bufferProvider: BufferProvider
  var objects: [[Any]]
  
  init?(mtkView: MTKView, textureName: String, modelName: String) {
    
    view = mtkView
    device = view.device!
    
    // Compile the functions and other state into a pipeline object.
    
    
    do {
      textureSky = try Renderer.buildTexture(pictureName: textureName, device)
    }
    catch {
      print("Unable to load texture from main bundle")
      return nil
    }

    do {
      arrSky = try Renderer.buildArr(arrName: modelName)
    }
    catch {
      print("Unable to load arr from main bundle")
      return nil
    }
    
    do {
      textureCoord = try Renderer.buildTexture(pictureName: "NasaSkyGrid", device)
    }
    catch {
      print("Unable to load texture from main bundle")
      return nil
    }
    
    do {
      arrCoord = try Renderer.buildArr(arrName: modelName)
    }
    catch {
      print("Unable to load arr from main bundle")
      return nil
    }
    
    
    
    vertexBufferSky = device.makeBuffer(bytes: arrSky, length: (arrSky.count * MemoryLayout<Float>.size), options: MTLResourceOptions())
    vertexBufferCoord = device.makeBuffer(bytes: arrCoord, length: (arrCoord.count * MemoryLayout<Float>.size), options: MTLResourceOptions())
    
    objects = [[arrSky,textureSky,vertexBufferSky,"Sky"],[arrCoord,textureCoord,vertexBufferCoord,"Coord"]]
    //objects = [[arrSky,textureSky,vertexBufferSky,"Sky"]]
    //objects = [[arrCoord,textureCoord,vertexBufferCoord,"Coord"]]
    // Make a texture sampler that wraps in both directions and performs bilinear filtering
    
    
    self.bufferProvider = BufferProvider(device: device, inflightBuffersCount: 3)
    do{
    renderPipelineState = try Renderer.buildRenderPipelineWithDevice(device, view: view)
    } catch {
      fatalError("asndkjasnd")
    }
    sampler = Renderer.buildSamplerStateWithDevice(device, addressMode: .repeat, filter: .linear)
    
    super.init()

  }
  
  class func buildRenderPipelineWithDevice(_ device: MTLDevice, view: MTKView) throws -> MTLRenderPipelineState {
    // The default library contains all of the shader functions that were compiled into our app bundle
    let library = device.newDefaultLibrary()!
    
    // Retrieve the functions that will comprise our pipeline
    let fragmentFunction = library.makeFunction(name: "basic_fragment")
    let vertexFunction = library.makeFunction(name: "basic_vertex")

    
    // A render pipeline descriptor describes the configuration of our programmable pipeline
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "Render Pipeline"
    pipelineDescriptor.sampleCount = view.sampleCount
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    
    return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
  }
  
  class func buildTexture(pictureName: String, _ device: MTLDevice) throws -> MTLTexture {
    let textureLoader = MTKTextureLoader(device: device)
    let path = Bundle.main.path(forResource: pictureName, ofType: "jpg")!
    let data = NSData(contentsOfFile: path)! as Data
    return try! textureLoader.newTexture(with: data, options: [MTKTextureLoaderOptionSRGB : (false as NSNumber)])
  }
  
  class func buildArr(arrName: String) throws -> [Float] {
    let url = Bundle.main.path(forResource: arrName, ofType: "arr")
    let json = NSData(contentsOfFile: url!)
    return try JSONSerialization.jsonObject(with: json! as Data, options: []) as! [Float]
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

  
  func render(_ view: MTKView, commandQueue: MTLCommandQueue, projectionMatrix: GLKMatrix4, worldModelMatrix: GLKMatrix4,worldModelMatrix1: GLKMatrix4) {
   
    // Our command buffer is a container for the work we want to perform with the GPU.
    let commandBuffer = commandQueue.makeCommandBuffer()
    let renderPassDescriptor = view.currentRenderPassDescriptor
    
    // Ask the view for a configured render pass descriptor. It will have a loadAction of
    // MTLLoadActionClear and have the clear color of the drawable set to our desired clear color.
    for object in objects{
    
      if let renderPassDescriptor = renderPassDescriptor {
        if (object[3] as! String) == "Sky" {
          renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        } else {
         renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        }
        // Create a render encoder to clear the screen and draw our objects
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        
        
        renderEncoder.pushDebugGroup("Draw sphere")
      
        // Since we specified the vertices of our triangles in counter-clockwise
        // order, we need to switch from the default of clockwise winding.
        //renderEncoder.setFrontFacing(.counterClockwise)
        // Set the pipeline state so the GPU knows which vertex and fragment function to invoke.
        renderEncoder.setRenderPipelineState(renderPipelineState)
      
        // Bind the buffer containing the array of vertex structures so we can
        // read it in our vertex shader.
        renderEncoder.setVertexBuffer(object[2] as? MTLBuffer, offset:0, at:0)
      
        // Bind our texture so we can sample from it in the fragment shader
        renderEncoder.setFragmentTexture(object[1] as? MTLTexture, at: 0)
      
        // Bind our sampler state so we can use it to sample the texture in the fragment shader
        renderEncoder.setFragmentSamplerState(sampler, at: 0)
      
        if (object[3] as! String == "Sky")  {
          print(object[3])
          let uniformBuffer = bufferProvider.nextUniformsBuffer(projectionMatrix, modelViewMatrix: worldModelMatrix)
          renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
          renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, at: 1)
        } else {
          print(object[3])
          let uniformBuffer = bufferProvider.nextUniformsBuffer(projectionMatrix, modelViewMatrix: worldModelMatrix)
          renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
          renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, at: 1)
        }
      
        // Issue the draw call to draw the indexed geometry of the mesh
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: (object[0] as AnyObject).count/5 )
        renderEncoder.popDebugGroup()
        // We are finished with this render command encoder, so end it.
        renderEncoder.endEncoding()
      
        // Tell the system to present the cleared drawable to the screen.
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
