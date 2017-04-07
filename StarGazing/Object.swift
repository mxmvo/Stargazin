//
//  Object.swift
//  StarGazing
//
//  Created by Maxim Oldenbeek on 07/04/2017.
//  Copyright © 2017 Maxim Oldenbeek. All rights reserved.
//

import Metal
import simd
import MetalKit
import GLKit

class object {
  var texture: MTLTexture
  var model: [Float]
  var vertexBuffer: MTLBuffer
  var name: String
  var pipeLine: MTLRenderPipelineState
  var show: Int = 1
  
  init(name: String, device: MTLDevice, view: MTKView, textureName: String, modelName: String, fragmentFunction: MTLFunction, vertexFunction: MTLFunction){
    self.name = name
    do
    {
    texture = try object.buildTexture(pictureName: textureName, device)
    model = try object.buildArr(arrName: modelName)
    pipeLine = try object.buildRenderPipelineWithDevice(device, view: view, fragmentFunction: fragmentFunction, vertexFunction: vertexFunction)
    } catch {
      fatalError("Initializing failes")
    }
    vertexBuffer = device.makeBuffer(bytes: model, length: model.count * MemoryLayout<Float>.size, options: MTLResourceOptions())
    
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
  
  class func buildRenderPipelineWithDevice(_ device: MTLDevice, view: MTKView, fragmentFunction: MTLFunction, vertexFunction: MTLFunction) throws -> MTLRenderPipelineState {
    
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

}
