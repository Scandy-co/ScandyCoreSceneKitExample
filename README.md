# Using ScandyCore.framework for iOS (iPhone X TrueDepth)
## ScandyCore License
Contact us to get a license to use ScandyCore. Then put the license string (without quotation marks) into file named ScandyCoreLicense.txt, and save it with UTF-8 encoding. In your project go to `Build Phases` -> `Copy Bundle Resources`, and add ScandyCoreLicense.txt to the list. 

In your application read the contents of the file into a string. Use the pointer to the ScandyCore object to call `setLicense`, passing the license string as an argument. If the return from this call is `SUCCESS`, everything is good; otherwise, you will receive the status `INVALID_LICENSE`, and you will not be able to use ScandyCore's functionality until you provide a valid license.

## Including ScandyCore in Your Project
Please extract the ScandyCore.framework.zip file and move the ScandyCore.framework file into the ScandyCoreiOSExample/Frameworks directory. 

The example app already has the `ScandyCore.framework` in `Framework Search Paths` and `ScandyCore.framework/Headers` in `Header Search Paths`. In your own project, please add your path to `ScandyCore.framework` in `Framework Search Paths` and `ScandyCore.framework/Headers` in `Header Search Paths` in Xcode. 

All basic functionality can be acheived by just importing the main header from the framework and including the interface header for access into the `ScandyCore` object.

```
// MyViewController.h
// example file

#include <scandy/core/IScandyCore.h>

#import <ScandyCore/ScandyCore.h>
...
// your code
...
// must include "IScandyCore.h" to use scandyCorePtr
ScandyCoreManager.scandyCorePtr->isRunning();
...
```

## ScandyCoreManager
We provide a `ScandyCoreManager` which contains a pointer to `ScandyCore` and another to `ScandyCoreCameraDelegate`. The `ScandyCore` object allows you to setup scan configurations, start scanning, stop scanning, generate mesh, and save the mesh. `ScandyCoreCameraDelegate` is used to manage the iPhone X's TrueDepth camera. 

Both of these objects are created automatically when `ScandyCoreManager` tries to access either of them for the first time. The ideal way to initialize them is to set the ScandyCore license before doing anything else.

```
ScandyCoreManager.scandyCorePtr->setLicense(licenseCString);
```

## Order is important
Before we set up the scanner we must be sure we have access to the TrueDepth camera.

```
// Make sure we have permission, or atleast request it
[ScandyCoreManager.scandyCameraDelegate hasPermission];
```

`[ScandyCoreManager.scandyCameraDelegate hasPermission]` returns `false` if the user has denied camera permission. It returns `true` when the user has given permission or the permission dialog is being presented. We suggest you request camera permissions in a user friendly way that makes the user aware of what's going on.

Once we have camera permissions then we can initialize the scanner:

```
[ScandyCoreManager initializeScanner:scandy::core::ScannerType::TRUE_DEPTH];
```

After the scanner is initialized, we can either start the preview or configure the scanning parameters like scan size, scan offset, etc. The order of these two actions is not important except that they must happen after `initializeScanner`.

From there we are ready to start the scanning process.

```
[ScandyCoreManager startPreview];
/* Allow user to adjust scan size, noise, offset, whatever.... */
[ScandyCoreManager startScanning];
```

**NOTE: Scan configurations must be finalized before calling `startScanning` beacuse they cannot be changed during scanning.**  

## Visualization
### Custom Views
If you want to create your own view, bind to the `onScanPreviewDidUpdate` callback of ScandyCore, like we do in this example!

```
ScandyCoreManager.scandyCorePtr->onScanPreviewDidUpdate = ^(
                                                                  const scandy::utilities::uchar4* img_data,
                                                                  const int width,
                                                                  const int height,
                                                                  const scandy::utilities::DepthTrackMetadata frame_metadata
                                                                  ) {
        // The img_data buffer is a buffer of uchar4 with r, g, b, a values ranging from 0 - 255
        // The img_data buffer is of size width x height
        copyRGBAToMyImage(img_data, width, height);
        
        // frame_metadata.computed_pose.homogeneous_matrix holds the last computed pose from Scandy Core
        
        // You can also get the translation part seperately
        scandy::utilities::float4 translation = scandy::utilities::translationVector(frame_metadata.computed_pose.homogeneous_matrix);
        };
```

**NOTE: Custom views are not fully supported in this release, so please use ScandyCoreView for best results.**
