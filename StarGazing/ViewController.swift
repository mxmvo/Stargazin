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
  var starSky: Renderer!
  var coord: Renderer!
  let panSensivity:Float = 1.0
  var lastPanLocation: CGPoint!
  var angleProjectionMatrix: Float = 85.0
  var projectionMatrix: GLKMatrix4 = GLKMatrix4Identity
  var worldModelMatrix: GLKMatrix4 = GLKMatrix4Identity
  var worldModelMatrix1: GLKMatrix4 = GLKMatrix4Identity

  var gestureRotationMatrix: GLKMatrix4 = GLKMatrix4Identity
  var ratio: Float = 0.0
  var commandQueue: MTLCommandQueue? = nil
  
  override func viewDidLoad() {
    self.ratio = Float(self.view.bounds.size.width / self.view.bounds.size.height)

    projectionMatrix = GLKMatrix4MakePerspective(angleProjectionMatrix/360.0*2*Float.pi, ratio, 0.01, 100.0)
    worldModelMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, 0.0)
    worldModelMatrix1 = GLKMatrix4MakeTranslation(0.0, 0.0, 0.0)

    
    let metalView = self.view as! MTKView
    metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)
    metalView.colorPixelFormat = .bgra8Unorm
    
    metalView.delegate = self
    metalView.device = device
    
    commandQueue = device.makeCommandQueue()
    
    starSky = Renderer(mtkView: metalView, textureName: "NasaSky", modelName: "StarSkyCelestial")
    //coord = Renderer(mtkView: metalView, textureName: "NasaSkyGrid", modelName: "StarSkyCelestial")
    setupGestures()
    
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


  //MARK: - Gesture related
  // 1
  func setupGestures() {
    let pan = UIPanGestureRecognizer(target: self, action: #selector(self.pan(_:)))
    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(self.pinch(_:)))
    self.view.addGestureRecognizer(pan)
    self.view.addGestureRecognizer(pinch)
  }
  
  // 2
  func pan(_ panGesture: UIPanGestureRecognizer) {
    if panGesture.state == UIGestureRecognizerState.changed {
      let pointInView = panGesture.location(in: self.view)
      // 3
      let xDelta = Float((lastPanLocation.x - pointInView.x)/self.view.bounds.width) * panSensivity
      let yDelta = Float((lastPanLocation.y - pointInView.y)/self.view.bounds.height) * panSensivity
      // 4
      //objectToDraw.gestureRotationMatrix = GLKMatrix4Multiply(modelMatrix(xDelta: xDelta, yDelta: yDelta), objectToDraw.gestureRotationMatrix)
      
      gestureRotationMatrix = GLKMatrix4Multiply(modelMatrix(xDelta: xDelta, yDelta: yDelta), gestureRotationMatrix)
      
      lastPanLocation = pointInView
    } else if panGesture.state == UIGestureRecognizerState.began {
      lastPanLocation = panGesture.location(in: self.view)
    }
  }
  
  func pinch(_ panGesture: UIPinchGestureRecognizer) {
    if panGesture.state == UIGestureRecognizerState.changed {
      let scale = panGesture.scale
      if 30 < angleProjectionMatrix && (Float(scale)-1) > 0 {
        angleProjectionMatrix -= (Float(scale)-1)/2
      } else if angleProjectionMatrix < 120 && (Float(scale)-1) < 0 {
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
    // respond to resize
  }
  
  @objc(drawInMTKView:)
  func draw(in metalView: MTKView)
  {
    
    starSky.render(metalView, commandQueue: commandQueue!, projectionMatrix: projectionMatrix, worldModelMatrix: GLKMatrix4Multiply(worldModelMatrix, gestureRotationMatrix), worldModelMatrix1: worldModelMatrix1)
    //coord.render(metalView, commandQueue: commandQueue!, projectionMatrix: projectionMatrix, worldModelMatrix: worldModelMatrix1)

  }

  
}

