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

  var gestureRotationMatrix: GLKMatrix4 = GLKMatrix4Identity
  var ratio: Float = 0.0
  var commandQueue: MTLCommandQueue? = nil
  
  var constel: object!
  var coord: object!
  var objects: [object] = []
  
  var gesture: Int = 1
  
  
  var locationManager: CLLocationManager!
  var latitude: Double = 0
  var longitude: Double = 0
  var gmtAngle:Double = 0
  var gmt: Double = 0
  var motionManager: CMMotionManager!
  var northPointingMatrix: GLKMatrix4 = GLKMatrix4MakeXRotation(-0.5*Float.pi)
  var levelingMatrix: GLKMatrix4 = GLKMatrix4Identity
  var locationMatrix: GLKMatrix4 = GLKMatrix4Identity


  
  @IBOutlet weak var longLatView: UILabel!
  @IBOutlet weak var viewingPosView: UILabel!
  @IBOutlet weak var gestureLabel: UIButton!
  
  
  override func viewDidLoad() {
    self.ratio = Float(self.view.bounds.size.width / self.view.bounds.size.height)

    projectionMatrix = GLKMatrix4MakePerspective(angleProjectionMatrix/360.0*2*Float.pi, ratio, 0.01, 100.0)
    //worldModelMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, 0.0)
    //worldModelMatrix = GLKMatrix4MakeYRotation(Float(50 / 360 * 2 * Double.pi))
    
    gmtAngle = (greenwichMeanSideRealTime() / 24 * 2 * Double.pi)
    //print(gmt)
    //print(gmt.truncatingRemainder(dividingBy: 1)*60)
    //print((gmt.truncatingRemainder(dividingBy: 1)*60).truncatingRemainder(dividingBy: 1)*60)
    worldModelMatrix = GLKMatrix4MakeYRotation(Float(gmtAngle))
    
    
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

    longLatView.textColor = .white
    viewingPosView.textColor = .white
    
    renderer = Renderer(mtkView: metalView)
    let starSky = object(name: "starSky", device: device, view: metalView, textureName: "NasaSky", modelName: "StarSkyCelestial", fragmentFunction: fragmentFunction!, vertexFunction: vertexFunction!)
    coord = object(name: "coord" , device: device, view: metalView, textureName: "NasaSkyGrid", modelName: "StarSkyCelestial", fragmentFunction: fragmentFunctionDis!, vertexFunction: vertexFunction!)
    //let boundaries = object(name: "coord" , device: device, view: metalView, textureName: "constellation_boundaries", modelName: "StarSkyCelestial", fragmentFunction: fragmentFunctionDis!, vertexFunction: vertexFunction!)
    constel = object(name: "constel", device: device, view: metalView, textureName: "NasaSkyConstellations", modelName: "StarSkyCelestial", fragmentFunction: fragmentFunctionDis!, vertexFunction: vertexFunction! )
    
    objects = [starSky, coord, constel]
    
    setupGestures()
    
    locationManager = CLLocationManager()
    locationManager.requestWhenInUseAuthorization()
    motionManager = CMMotionManager()
    motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical)
    motionManager.startMagnetometerUpdates()

    
    if (CLLocationManager.locationServicesEnabled()) {
      locationManager.delegate = self
      locationManager.requestLocation()

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
  
  
  //MARK: Location Manager

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    latitude = round(1000000*manager.location!.coordinate.latitude) / 1000000
    longitude = round(1000000*manager.location!.coordinate.longitude) / 1000000
    
    
    // Lotitude and Longitude for Leh, Ladakh
    //latitude = 34.122858
    //longitude = 77.553433
    
    longLatView.text = "Lat: \(latitude)  Lon: \(longitude)"
    let longMatrix = GLKMatrix4MakeYRotation(Float(longitude / 360 * 2 * Double.pi))
    let latMatrix = GLKMatrix4MakeXRotation(Float(latitude / 360 * 2 * Double.pi))
    locationMatrix = GLKMatrix4Multiply(latMatrix, longMatrix)
    
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Failed to find user's location: \(error.localizedDescription)")
  }
  
  //MARK: MTKView
  
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
    let magneticDataLocation = self.locationManager.heading
    //print("location \(String(describing: magneticDataLocation))")
    //print("magnetometer \(String(describing: magneticData))")

    if deviceMotionData != nil && magneticDataLocation != nil {

      let gravity = gravityVector(gravity: deviceMotionData!)
      let zenith = GLKVector4MultiplyScalar(gravity, -1)
      //let north = northVectorDeviceMotion(gravity: gravity, heading: magneticData!)
      let north = northVector(gravity: gravity, heading: magneticDataLocation!)
      let east = GLKVector4CrossProduct(gravity, north)
      levelingMatrix = makeSkyRotationMatrix(x: east, y: GLKVector4Negate(north), z: gravity)
      
      //GLKMatrix4MultiplyVector4(levelingMatrix, north)
      let rotationMatrix = GLKMatrix4Multiply(locationMatrix, worldModelMatrix)
      angleView(north: GLKMatrix4MultiplyVector4(rotationMatrix, north) , east: GLKMatrix4MultiplyVector4(rotationMatrix, east), zenith: zenith)
      //angleView(north: north , east: east, zenith: zenith)
    }
    
    

    if gesture == 1 {
      let skyRotationMatrix = GLKMatrix4Multiply( gestureRotationMatrix , GLKMatrix4Multiply(locationMatrix, worldModelMatrix))
    renderer.render(metalView, commandQueue: commandQueue!, projectionMatrix: projectionMatrix, worldModelMatrix: skyRotationMatrix, objects: objectRender)
    } else {
      let skyRotationMatrix = GLKMatrix4Multiply( levelingMatrix , GLKMatrix4Multiply(locationMatrix, worldModelMatrix))
    renderer.render(metalView, commandQueue: commandQueue!, projectionMatrix: projectionMatrix,
    worldModelMatrix: skyRotationMatrix, objects: objectRender)
    
    
      
    }
    
    
  }
  
  //MARK: Buttons
  
  @IBAction func constellations(_ sender: UIButton) {
    constel.show = (constel.show + 1) % 2
    
  }
  @IBAction func coordinates(_ sender: Any) {
    coord.show = (coord.show + 1) % 2
  }
  
  @IBAction func gestureAutomaticView(_ sender: Any) {
    gesture = (gesture + 1) % 2
    if gesture == 0 {
      //gestureLabel.setTitle("Free Movement", for: .normal)
      gestureLabel.setImage(#imageLiteral(resourceName: "finger"), for: .normal)
      
      motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical)
      motionManager.startMagnetometerUpdates()
      
      if (CLLocationManager.locationServicesEnabled()) {
        locationManager.requestLocation()
        locationManager.startUpdatingHeading()
      }
    } else {
      //gestureLabel.setTitle("Point Movement", for: .normal)
      gestureLabel.setImage(#imageLiteral(resourceName: "eye"), for: .normal)
      motionManager.stopDeviceMotionUpdates()
      motionManager.stopMagnetometerUpdates()
      locationManager.stopUpdatingLocation()
    }
  }
  
  //MARK: Matrix Calculations
  
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

  
  

  /// Return the projection of the vector on the plane defined by planerVector.
  func projectVector4Plane(vector: GLKVector4, planarVector: GLKVector4) -> GLKVector4 {
    // vector = projectionOnPlane + projectionOnPlanarVector => projectionOnPlane = vector - projectionOnPlanarVector
    let proj = GLKVector4Project(vector, planarVector)
    return GLKVector4Subtract(vector, proj)
  }
  
  /// Return angles between two vectors
  func angleBetweenVectors4(vector1: GLKVector4, vector2: GLKVector4) -> Double {
    
    let angle = acos(Double(GLKVector4DotProduct(vector1, vector2) / (GLKVector4Length(vector1) * GLKVector4Length(vector2) )))
    return  ( angle * 360.0 ) / ( 2.0 * Double.pi )
  }
  
  func angleView(north: GLKVector4, east: GLKVector4, zenith: GLKVector4) -> [Double] {
    let pointVector = GLKVector4Make(0, 0, -1, 0)
    let parallelNorth = projectVector4Plane(vector: pointVector, planarVector: north)
    let parallelEast = projectVector4Plane(vector: pointVector, planarVector: east)
    
    //print("east: \(parallelEast.v), north: \(parallelNorth.v), zenith: \(zenith.v)")
    
    var angleLongitude:Double = 0
    var angleLattitude:Double = 0
    
    // Check if we are looking east or west
    let angleLon = angleBetweenVectors4(vector1: parallelNorth, vector2: zenith)
    if GLKVector4DotProduct(parallelNorth, east) > 0 {
      angleLongitude = (angleLon + longitude + gmtAngle).truncatingRemainder(dividingBy: 360)
    } else {
      angleLongitude = (360 - angleLon + longitude + gmtAngle).truncatingRemainder(dividingBy: 360)
    }
    
    // Check for northern hemisphere
    // 
    
    let angleLat = angleBetweenVectors4(vector1: parallelEast, vector2: north)
      angleLattitude = 90 - angleLat
//    // Check for southenh hemisphere
//    else {
//      if angleLat < 90 {
//        angleLattitude = -1 * angleLat
//      } else {
//        angleLattitude = -180 + angleLat
//      }
//    }
    viewingPosView.text = "lat: \(round(angleLattitude*100) / 100) lon: \(round(angleLongitude*100)/100)"
    return [1.0]
  }
  
  
  func makeSkyRotationMatrix(x: GLKVector4, y: GLKVector4, z: GLKVector4) -> GLKMatrix4 {
    return GLKMatrix4MakeWithColumns(x, y, z, GLKVector4Make(0.0, 0.0, 0.0, 1.0))
  }
  
  func modelMatrix(xDelta: Float, yDelta: Float) -> GLKMatrix4 {
    var matrixRot = GLKMatrix4MakeXRotation(yDelta)
    matrixRot = GLKMatrix4RotateY(matrixRot, xDelta)
    return matrixRot
  }
  
  
  /// Calculates the greenwichMeanSideRealTime
  func greenwichMeanSideRealTime() -> Double {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone.current
    dateFormatter.locale = Locale.current
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let UT1 = dateFormatter.date(from: "2000-01-01 13:00:00")
    let timeDifference = Date().timeIntervalSince(UT1!)
    let GMT = (18.697374558 + 24.06570982441908 * (timeDifference / 3600 / 24)).truncatingRemainder(dividingBy: 24)
    return GMT
  }
  
}

