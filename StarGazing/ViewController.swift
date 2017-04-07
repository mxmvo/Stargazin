//
//  ViewController.swift
//  StarGazing
//
//  Created by Maxim Oldenbeek on 07/04/2017.
//  Copyright © 2017 Maxim Oldenbeek. All rights reserved.
//

import UIKit
import MetalKit
import GLKit

class ViewController: UIViewController, MTKViewDelegate {

  var device: MTLDevice = MTLCreateSystemDefaultDevice()!
  var renderer: Renderer!
  
  let panSensivity:Float = 1.0
  var lastPanLocation: CGPoint!
  var angleProjectionMatrix: Float = 40.0
  var projectionMatrix: GLKMatrix4 = GLKMatrix4Identity
  var worldModelMatrix: GLKMatrix4 = GLKMatrix4Identity
  var worldModelMatrix1: GLKMatrix4 = GLKMatrix4Identity

  var gestureRotationMatrix: GLKMatrix4 = GLKMatrix4Identity
  var ratio: Float = 0.0
  var commandQueue: MTLCommandQueue? = nil
  
  var constel: object
  var objects: [object] = []
  
  
  
  override func viewDidLoad() {
    self.ratio = Float(self.view.bounds.size.width / self.view.bounds.size.height)

    projectionMatrix = GLKMatrix4MakePerspective(angleProjectionMatrix/360.0*2*Float.pi, ratio, 0.01, 100.0)
    worldModelMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, 0.0)
    
    let metalView = self.view as! MTKView
    metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)
    metalView.colorPixelFormat = .bgra8Unorm
    
    metalView.delegate = self
    metalView.device = device
    
    commandQueue = device.makeCommandQueue()
    
    // The default library contains all of the shader functions that were compiled into our app bundle
    let library = device.newDefaultLibrary()!
    
    // Retrieve the functions that will comprise our pipeline
    let fragmentFunction = library.makeFunction(name: "basic_fragment")
    let fragmentFunctionDis = library.makeFunction(name: "basic_fragment_dis")
    let vertexFunction = library.makeFunction(name: "basic_vertex")

    
    
    renderer = Renderer(mtkView: metalView)
    let starSky = object(name: "starSky", device: device, view: metalView, textureName: "NasaSky", modelName: "StarSkyCelestial", fragmentFunction: fragmentFunction!, vertexFunction: vertexFunction!)
    let coord = object(name: "coord" , device: device, view: metalView, textureName: "NasaSkyGrid", modelName: "StarSkyCelestial", fragmentFunction: fragmentFunctionDis!, vertexFunction: vertexFunction!)
    constel = object(name: "constel", device: device, view: metalView, textureName: "NasaSkyConstellations", modelName: "StarSkyCelestial", fragmentFunction: fragmentFunctionDis!, vertexFunction: vertexFunction! )
    
    objects = [starSky,coord,constel]
    
    setupGestures()
    super.viewDidLoad()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


  //MARK: - Gesture related
  func setupGestures() {
    let pan = UIPanGestureRecognizer(target: self, action: #selector(self.pan(_:)))
    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(self.pinch(_:)))
    self.view.addGestureRecognizer(pan)
    self.view.addGestureRecognizer(pinch)
  }
  
  func pan(_ panGesture: UIPanGestureRecognizer) {
    if panGesture.state == UIGestureRecognizerState.changed {
      let pointInView = panGesture.location(in: self.view)
      let xDelta = Float((lastPanLocation.x - pointInView.x)/self.view.bounds.width) * panSensivity
      let yDelta = Float((lastPanLocation.y - pointInView.y)/self.view.bounds.height) * panSensivity
      
      gestureRotationMatrix = GLKMatrix4Multiply(modelMatrix(xDelta: xDelta, yDelta: yDelta), gestureRotationMatrix)
      
      lastPanLocation = pointInView
    } else if panGesture.state == UIGestureRecognizerState.began {
      lastPanLocation = panGesture.location(in: self.view)
    }
  }
  
  func pinch(_ panGesture: UIPinchGestureRecognizer) {
    if panGesture.state == UIGestureRecognizerState.changed {
      let scale = panGesture.scale
      if 10 < angleProjectionMatrix && (Float(scale)-1) > 0 {
        angleProjectionMatrix -= (Float(scale)-1)/2
      } else if angleProjectionMatrix < 70 && (Float(scale)-1) < 0 {
        angleProjectionMatrix -= (Float(scale)-1)*2
      }
      projectionMatrix = GLKMatrix4MakePerspective(angleProjectionMatrix/360.0*2*Float.pi, ratio, 0.01, 100.0)
    }
  }
  
  func modelMatrix(xDelta: Float, yDelta: Float) -> GLKMatrix4 {
    var matrixRot = GLKMatrix4MakeXRotation(yDelta)
    matrixRot = GLKMatrix4RotateY(matrixRot, xDelta)
    return matrixRot
  }
  
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    self.ratio = Float(self.view.bounds.size.width / self.view.bounds.size.height)
  }
  
  @objc(drawInMTKView:)
  func draw(in metalView: MTKView)
  {
    var objectRender = [object]()
    for object in objects{
      if object.show == 1 {
        objectRender.append(object)
      }
    }
    renderer.render(metalView, commandQueue: commandQueue!, projectionMatrix: projectionMatrix, worldModelMatrix: gestureRotationMatrix, objects: objectRender)
  }
  @IBAction func constellations(_ sender: UIButton) {
    constel.show = (constel.show + 1) % 2
    
  }
}

