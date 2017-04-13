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
import CoreLocation
import CoreMotion

class ViewController: UIViewController, MTKViewDelegate, CLLocationManagerDelegate {

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
  
  var constel: object!
  var objects: [object] = []
  
  var compassManager: CLLocationManager!
  var motionManager: CMMotionManager!
  var northPointingMatrix: GLKMatrix4 = GLKMatrix4MakeXRotation(-0.5*Float.pi)
  var levelingMatrix: GLKMatrix4 = GLKMatrix4Identity


  
  
  
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
    
    objects = [starSky, coord, constel]
    
    setupGestures()
    
    compassManager = CLLocationManager()
    motionManager = CMMotionManager()
    motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical)
    motionManager.startMagnetometerUpdates()
    

    
    if (CLLocationManager.headingAvailable()) {
      compassManager.headingFilter = 1
      compassManager.startUpdatingHeading()
      compassManager.delegate = self
    }
    
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
  
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    //northPointingMatrix = GLKMatrix4MakeYRotation(Float(heading.trueHeading / 360.0 * 2.0 * Double.pi))
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
    
    let deviceMotionData = self.motionManager.deviceMotion?.gravity
    let magneticData = self.motionManager.deviceMotion?.magneticField

    if deviceMotionData != nil && magneticData != nil && compassManager.heading != nil{

      //levelingMatrix = makeLevelingMatrix(gravity: deviceMotionData!)
      let gravity = gravityVector(gravity: deviceMotionData!)
      let north = northVectorDeviceMotion(gravity: gravity, heading: magneticData!)
      print(north.v)
      
      levelingMatrix = makeSkyRotationMatrix(x: GLKVector4CrossProduct(gravity, north), y: gravity, z: north)
      
      print(compassManager.heading!.trueHeading)
    }
    let skyRotationMatrix = GLKMatrix4Multiply( levelingMatrix , northPointingMatrix)

    //renderer.render(metalView, commandQueue: commandQueue!, projectionMatrix: projectionMatrix, worldModelMatrix: gestureRotationMatrix, objects: objectRender)
    renderer.render(metalView, commandQueue: commandQueue!, projectionMatrix: projectionMatrix, worldModelMatrix: skyRotationMatrix, objects: objectRender)
  }
  
  @IBAction func constellations(_ sender: UIButton) {
    constel.show = (constel.show + 1) % 2
    
  }
  
  func makeLevelingMatrix(gravity: CMAcceleration) -> GLKMatrix4 {

    let rotX = atan2(gravity.z, gravity.y)
    let rotZ = atan2(gravity.x, gravity.y)
    
    let rotXMatrix = GLKMatrix4MakeXRotation(Float(rotX))
    let rotZMatrix = GLKMatrix4MakeZRotation(Float(rotZ))
    return GLKMatrix4Multiply(rotXMatrix, rotZMatrix)

  }
  func gravityVector(gravity: CMAcceleration) -> GLKVector4 {
    return GLKVector4Make(Float(gravity.x), Float(gravity.y), Float(gravity.z), 0)
  }
  
  func northVector(gravity: GLKVector4, heading: CLHeading) -> GLKVector4 {
    let magn = GLKVector4Make(Float(heading.x), Float(heading.y), Float(heading.z), 0)
    
    let proj = GLKVector4Project(magn, gravity)
    
    return GLKVector4Normalize(GLKVector4Subtract(magn, proj))
  }
  
  func northVectorDeviceMotion(gravity: GLKVector4, heading: CMCalibratedMagneticField) -> GLKVector4 {
    let magn = GLKVector4Make(Float(heading.field.x), Float(heading.field.y), Float(heading.field.z), 0)
    
    let proj = GLKVector4Project(magn, gravity)
    
    return GLKVector4Normalize(GLKVector4Subtract(magn, proj))
  }
  
  func makeSkyRotationMatrix(x: GLKVector4, y: GLKVector4, z: GLKVector4) -> GLKMatrix4 {
    return GLKMatrix4MakeWithColumns(x, y, z, GLKVector4Make(0.0, 0.0, 0.0, 1.0))
  }
  
}

