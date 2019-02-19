//
//  GameViewController.m
//  ScandyCoreSceneKitExample
//
//  Created by H. Cole Wiley on 11/20/18.
//  Copyright © 2018 Scandy. All rights reserved.
//

#include <scandy/core/IScandyCore.h>
#include <scandy/utilities/vector_math.h>

#import "GameViewController.h"

#import <ScandyCore/ScandyCore.h>

@interface GameViewController () <ScandyCoreManagerDelegate>
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) NSString *filePath;
@end

@implementation GameViewController

- (void)onVisualizerReady:(bool)createdVisualizer {
  NSLog(@"onVisualizerReady");
}
- (void) onScannerReady:(scandy::core::Status) status {
  NSLog(@"onScannerReady");
}
- (void) onPreviewStart:(scandy::core::Status) status {
  NSLog(@"onPreviewStart");
}
- (void) onScannerStart:(scandy::core::Status) status {
  NSLog(@"onScannerStart");
}
- (void) onScannerStop:(scandy::core::Status) status {
  [ScandyCoreManager generateMesh];
}
- (void) onGenerateMesh:(scandy::core::Status) status {
  // Call save to a tmp directory
  NSString *fileName = [NSString stringWithFormat:@"tmp.obj"];
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  _filePath = [documentsDirectory stringByAppendingPathComponent:fileName];

  [ScandyCoreManager saveMesh:_filePath];
}
- (void) onSaveMesh:(scandy::core::Status) status {
  // Load the saved mesh into SceneKit
  NSDictionary *opts = @{SCNSceneSourceConvertToYUpKey: @YES, SCNSceneSourceConvertUnitsToMetersKey: @1.0};
  NSURL *url = [NSURL fileURLWithPath:_filePath];
  NSError *error;
  SCNScene *scene = [SCNScene sceneWithURL:url options:opts error:&error];
  if(error) {
    NSLog(@"%@",[error localizedDescription]);
  }

  // retrieve the SCNView
  SCNView *scnView = (SCNView *)self.view;

  SCNNode *modelNode = [[SCNNode alloc] init];
  NSArray *nodeArray = [scene.rootNode childNodes];
  for (SCNNode *eachChild in nodeArray) {
    [modelNode addChildNode:eachChild];
  }

  SCNMaterial *material = [SCNMaterial material];
  material.litPerPixel = true;
  material.doubleSided = true;
  material.cullMode = SCNCullModeBack;

  SCNMaterial *backMaterial = [SCNMaterial material];
  backMaterial.litPerPixel = false;
  backMaterial.doubleSided = true;
  backMaterial.cullMode = SCNCullModeFront;
  backMaterial.diffuse.contents = [UIColor lightGrayColor];

  modelNode.geometry.materials = @[material, backMaterial];

  SCNVector3 initialPos = modelNode.position;
  SCNVector3 min = SCNVector3Zero;
  SCNVector3 max = SCNVector3Zero;
  [modelNode getBoundingBoxMin:&min max:&max];

  modelNode.pivot = SCNMatrix4MakeTranslation(
                                              min.x + (max.x - min.x)/2,
                                              min.y + (max.y - min.y)/2,
                                              min.z + (max.z - min.z)/2
                                              );
  float correctX = (min.x + (max.x - min.x)/2);
  float correctY = -min.y;//(min.y + (max.y - min.y)/2);
  float correctZ = (min.z + (max.z - min.z)/2);


  if ([modelNode convertVector:SCNVector3Make(0,0,1) fromNode:scnView.scene.rootNode].z < 0 ){
    // if blue local z-axis is pointing downwards
    modelNode.position = SCNVector3Make(initialPos.x - correctX, initialPos.y - correctY, initialPos.z - correctZ);
  } else {
    // if blue local z-axis is pointing upwards
    modelNode.position = SCNVector3Make(initialPos.x + correctX, initialPos.y + correctY, initialPos.z + correctZ);
  }

  SCNMatrix4 flip = modelNode.transform;
  flip.m33 *= -1;
  modelNode.transform = flip;

  // Apparently this ship is HUGE
  modelNode.scale = SCNVector3Make( 10, 10, 10);

  // animate the 3d object
  [modelNode runAction:[SCNAction repeatAction:[SCNAction rotateByX:0 y:2 z:0 duration:1] count:6]];

  [scnView.scene.rootNode addChildNode:modelNode];
}

// NOTE: only used in scan mode v2, which is currently experimental
- (void) onVolumeMemoryDidUpdate:(const float) percent_full {
  NSLog(@"ScandyCoreViewController::onVolumeMemoryDidUpdate %f", percent_full);
}

// Network client connected callback
- (void)onClientConnected:(NSString *)host {
  NSLog(@"onClientConnected");
}

- (void) onTrackingDidUpdate:(float)confidence withTracking:(bool)is_tracking{
  // NOTE: this is a very active callback, so don't log it as it will slow everything to a crawl
  // NSLog(@"onTrackingDidUpdate");
}

/**
 thanks to: https://gist.github.com/PaulSolt/739132/b1343cf2970a56ebe2840af31133052118dbe8df
 */
UIImage * convertBitmapRGBA8ToUIImage(char* buffer, int width, int height ) {
  size_t bufferLength = width * height * 4;
  CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, bufferLength, NULL);
  size_t bitsPerComponent = 8;
  size_t bitsPerPixel = 32;
  size_t bytesPerRow = 4 * width;

  CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
  if(colorSpaceRef == NULL) {
    NSLog(@"Error allocating color space");
    CGDataProviderRelease(provider);
    return nil;
  }

  CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
  CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;

  CGImageRef iref = CGImageCreate(width,
                                  height,
                                  bitsPerComponent,
                                  bitsPerPixel,
                                  bytesPerRow,
                                  colorSpaceRef,
                                  bitmapInfo,
                                  provider,  // data provider
                                  NULL,    // decode
                                  YES,      // should interpolate
                                  renderingIntent);

  uint32_t* pixels = (uint32_t*)malloc(bufferLength);

  if(pixels == NULL) {
    NSLog(@"Error: Memory not allocated for bitmap");
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(iref);
    return nil;
  }

  CGContextRef context = CGBitmapContextCreate(pixels,
                                               width,
                                               height,
                                               bitsPerComponent,
                                               bytesPerRow,
                                               colorSpaceRef,
                                               bitmapInfo);

  if(context == NULL) {
    NSLog(@"Error context not created");
    free(pixels);
  }

  UIImage *image = nil;
  if(context) {

    // NOTE images come in roated 90 degs
    CGContextTranslateCTM( context, 0.5f * width, 0.5f * height ) ;
    CGContextRotateCTM (context, -1.5708);
    CGContextTranslateCTM( context, -0.5f * width, -0.5f * height ) ;

    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, width, height), iref);

    CGImageRef imageRef = CGBitmapContextCreateImage(context);

    // Support both iPad 3.2 and iPhone 4 Retina displays with the correct scale
    if([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
      float scale = [[UIScreen mainScreen] scale];
      image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    } else {
      image = [UIImage imageWithCGImage:imageRef];
    }

    CGImageRelease(imageRef);
    CGContextRelease(context);
  }

  CGColorSpaceRelease(colorSpaceRef);
  CGImageRelease(iref);
  CGDataProviderRelease(provider);

  if(pixels) {
    free(pixels);
  }
  return image;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  // create a new scene
  SCNScene *scene = [SCNScene sceneNamed:@"art.scnassets/ship.scn"];

  // create and add a camera to the scene
  SCNNode *cameraNode = [SCNNode node];
  cameraNode.camera = [SCNCamera camera];
  cameraNode.camera.zNear = 0.01;
  [scene.rootNode addChildNode:cameraNode];

  // place the camera
  cameraNode.position = SCNVector3Make(0, 0, 10);

  // create and add a light to the scene
  SCNNode *lightNode = [SCNNode node];
  lightNode.light = [SCNLight light];
  lightNode.light.type = SCNLightTypeOmni;
  lightNode.position = SCNVector3Make(0, 15, -15);
  [scene.rootNode addChildNode:lightNode];

  // create and add an ambient light to the scene
  SCNNode *ambientLightNode = [SCNNode node];
  ambientLightNode.light = [SCNLight light];
  ambientLightNode.light.type = SCNLightTypeAmbient;
  ambientLightNode.light.color = [UIColor darkGrayColor];
  [scene.rootNode addChildNode:ambientLightNode];

  // retrieve the SCNView
  SCNView *scnView = (SCNView *)self.view;

  // set the scene to the view
  scnView.scene = scene;

  // allows the user to manipulate the camera
  scnView.allowsCameraControl = YES;

  // show statistics such as fps and timing information
  scnView.showsStatistics = YES;

  // configure the view
  scnView.backgroundColor = [UIColor blackColor];

  // add a tap gesture recognizer
  UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
  NSMutableArray *gestureRecognizers = [NSMutableArray array];
  [gestureRecognizers addObject:tapGesture];
  [gestureRecognizers addObjectsFromArray:scnView.gestureRecognizers];
  scnView.gestureRecognizers = gestureRecognizers;

  /**
   Setup Scandy Core and the additonal stuff it needs to run properly
   */
  // Make ourselves into a ScandyCoreManagerDelegate
  [ScandyCoreManager setScandyCoreDelegate:self];

  [self startPreview];
}

- (void)setLicense {
  // Get license to use ScandyCore
  NSString *licensePath = [[NSBundle mainBundle] pathForResource:@"ScandyCoreLicense" ofType:@"txt"];
  NSString *licenseString = [NSString stringWithContentsOfFile:licensePath encoding:NSUTF8StringEncoding error:NULL];

  // convert license to cString
  const char* licenseCString = [licenseString cStringUsingEncoding:NSUTF8StringEncoding];

  // Get access to use ScandyCore
  ScandyCoreManager.scandyCorePtr->setLicense(licenseCString);
}


- (void)requestCamera {
  if ( [ScandyCoreManager.scandyCameraDelegate hasPermission]  )
  {
    NSLog(@"user has granted permission to camera!");
  } else {
    NSLog(@"user has denied permission to camera");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Camera permission"
                                                    message:@"We need to access the camera to make a 3D scan. Go to settings and allow permission."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
  }
}

// here you can set the initial scan state with things like scan size, resolution, bounding box offset
// from camera, viewport orientation and so on. All these things can be changed programmatically while
// the preview is running as well, but they cannot change during an active scan.
- (void)setupScanConfiguration{

  // The scan size represents the width, height, and depth (in meters) of the scan volume's bounding box, which
  // must all be the same value.
  // set the initial scan size to 0.5m x 0.5m x 0.5m
  float scan_size = 0.5;
  ScandyCoreManager.scandyCorePtr->setScanSize(scan_size);

  // Set the bounding box offset 0.2 meters from the sensor to be able to use the full bounding box for
  // scanning since the TrueDepth sensor can't see before about 0.15m
  // We recommend not setting this too much farther than you need to because the quality of depth data
  // degrades farther away from the sensor
  float offset = 0.2;
  ScandyCoreManager.scandyCorePtr->setBoundingBoxOffset(offset);

  // Set the orientation to up upright and mirrored (EXIFOrienation::SIX). This is the default orientation
  // that's set for the TrueDepth sensor in initializeScanner because it's easiest to use when scanning with
  // the front-facing sensor while looking at the screen. You can change it to one of the other seven orientations
  // here. For example, if you want to cast the screen while scanning, using EXIFOrientation::SEVEN would allow a
  // more natural view for when the sensor is facing away from you.
  ScandyCoreManager.scandyCorePtr->setDepthCameraEXIFOrientation(scandy::utilities::EXIFOrientation::SIX);
}

- (void) startPreview {
  [self setLicense];
  
  // Make sure we are not already running and that we have a valid capture directory
  if( !ScandyCoreManager.scandyCorePtr->isRunning()){
    dispatch_async(dispatch_get_main_queue(), ^{

      // Make sure we have camera permissions
      [self requestCamera];

      auto scannerType = scandy::core::ScannerType::TRUE_DEPTH;
      auto status = [ScandyCoreManager initializeScanner:scannerType];
      if (status != scandy::core::Status::SUCCESS) {
        auto reason = [[NSString alloc] initWithFormat:@"%s", scandy::core::getStatusString(status).c_str() ];
        NSLog(@"failed to initialize scanner with reason: %@", reason);
      }

      // NOTE: it's important to call this after scandyCorePtr->initializeScanner() because
      // we need the scanner to have been initialized so that the configuration changes will persist
      [self setupScanConfiguration];

      /**
       IMPORTANT: You must assign this callback before calling [ScandyCoreManager startPreview];
       */
      ScandyCoreManager.scandyCorePtr->onScanPreviewDidUpdate = ^(
                                                                  const scandy::utilities::uchar4* img_data,
                                                                  const int width,
                                                                  const int height,
                                                                  const scandy::utilities::DepthTrackMetadata frame_metadata
                                                                  ) {
        // The img_data buffer is a buffer of uchar4 with r, g, b, a values ranging from 0 - 255
        // The img_data buffer is of size width x height
        @autoreleasepool {
          SCNView *scnView = (SCNView *)self.view;

          // Ands lets rotate the ship to match the tracking
          SCNNode *ship = [scnView.scene.rootNode childNodeWithName:@"ship" recursively:YES];
          SCNMatrix4 mat = SCNMatrix4Identity;
          // frame_metadata.computed_pose.homogeneous_matrix holds the last computed pose from Scandy Core
          mat.m11 = frame_metadata.computed_pose.homogeneous_matrix.v4[0].s[0];
          mat.m12 = frame_metadata.computed_pose.homogeneous_matrix.v4[0].s[1];
          mat.m13 = frame_metadata.computed_pose.homogeneous_matrix.v4[0].s[2];
          mat.m14 = frame_metadata.computed_pose.homogeneous_matrix.v4[0].s[3];

          mat.m21 = frame_metadata.computed_pose.homogeneous_matrix.v4[1].s[0];
          mat.m22 = frame_metadata.computed_pose.homogeneous_matrix.v4[1].s[1];
          mat.m23 = frame_metadata.computed_pose.homogeneous_matrix.v4[1].s[2];
          mat.m24 = frame_metadata.computed_pose.homogeneous_matrix.v4[1].s[3];

          mat.m31 = frame_metadata.computed_pose.homogeneous_matrix.v4[2].s[0];
          mat.m32 = frame_metadata.computed_pose.homogeneous_matrix.v4[2].s[1];
          mat.m33 = frame_metadata.computed_pose.homogeneous_matrix.v4[2].s[2];
          mat.m34 = frame_metadata.computed_pose.homogeneous_matrix.v4[2].s[3];

          mat.m41 = frame_metadata.computed_pose.homogeneous_matrix.v4[3].s[0];
          mat.m42 = frame_metadata.computed_pose.homogeneous_matrix.v4[3].s[1];
          mat.m43 = frame_metadata.computed_pose.homogeneous_matrix.v4[3].s[2];
          mat.m44 = frame_metadata.computed_pose.homogeneous_matrix.v4[3].s[3];
          ship.transform = mat;

          // You can also get the translation part seperately
          scandy::utilities::float4 translation = scandy::utilities::translationVector(frame_metadata.computed_pose.homogeneous_matrix);

          // You can also get the orientation vector from the matrix
          scandy::utilities::float3 orientation;
          scandy::utilities::get_orientation(frame_metadata.computed_pose.homogeneous_matrix, orientation);

          /** NOTE: this is a widly in-effecient function and only meant to illustrate how you CAN get the data.
           You should implement something that doesn't constantly destroy the inbetween buffers
           and more effeciently copies the buffer over.
           */
          UIImage *image = convertBitmapRGBA8ToUIImage((char*)img_data, width, height);
          scnView.scene.background.contents = image;
        }
      };

      // Actually start the preview
      [ScandyCoreManager startPreview];

    });
  }
}

- (void) handleTap:(UIGestureRecognizer*)gestureRecognize
{
  // retrieve the SCNView
  SCNView *scnView = (SCNView *)self.view;

  // check what nodes are tapped
  CGPoint p = [gestureRecognize locationInView:scnView];
  NSArray *hitResults = [scnView hitTest:p options:nil];

  // check that we clicked on at least one object
  if([hitResults count] > 0){
    // retrieved the first clicked object
    SCNHitTestResult *result = [hitResults objectAtIndex:0];

    // get its material
    SCNMaterial *material = result.node.geometry.firstMaterial;

    // highlight it
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.5];

    // on completion - unhighlight
    [SCNTransaction setCompletionBlock:^{
      [SCNTransaction begin];
      [SCNTransaction setAnimationDuration:0.5];

      material.emission.contents = [UIColor blackColor];

      [SCNTransaction commit];
    }];

    material.emission.contents = [UIColor redColor];

    [SCNTransaction commit];
  }

  scandy::core::ScanState scanState = ScandyCoreManager.scandyCorePtr->getScanState();
  if( scanState == scandy::core::ScanState::PREVIEWING ){
    [ScandyCoreManager startScanning];
  } else if( scanState == scandy::core::ScanState::SCANNING ){
    [ScandyCoreManager stopScanning];
  } else if( scanState == scandy::core::ScanState::VIEWING ){
    [ScandyCoreManager startPreview];
  }
}

- (BOOL)shouldAutorotate
{
  return YES;
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    return UIInterfaceOrientationMaskAllButUpsideDown;
  } else {
    return UIInterfaceOrientationMaskAll;
  }
}

@end
