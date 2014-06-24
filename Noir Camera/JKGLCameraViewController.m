//
//  JKGLCameraViewController.m
//  Noir Camera
//
//  Created by Jay on 5/8/14.
//  Copyright (c) 2014 Zihae. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "JKGLCameraViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <GLKit/GLKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "CZGPerlinGenerator.h"



@interface JKGLCameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>
{
    AVCaptureSession *_session;
    dispatch_queue_t captureQueue;
    dispatch_queue_t faceDetectQueue;

    CIContext *_coreImageContext;
    EAGLContext *_context;
    
    __weak IBOutlet GLKView *_glView;

    CZGPerlinGenerator *_perlin;
    
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_assetWriterAudioInput;
    AVAssetWriterInputPixelBufferAdaptor *_assetWriterPixelBufferInput;
    BOOL _isWriting;
    CMTime currentSampleTime;
}

- (IBAction)record:(id)sender;

@end

@implementation JKGLCameraViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    _glView.context = _context;
    float screenWidth = [[UIScreen mainScreen] bounds].size.height;
      _glView.contentScaleFactor = 640.0/screenWidth;
    [_glView sizeThatFits:CGSizeMake(320.0, 106.0)];
    _coreImageContext = [CIContext contextWithEAGLContext:_context];
  
    
    self.preferredFramesPerSecond = 10;
    
    
    
    _session = [[AVCaptureSession alloc]init];
    [_session beginConfiguration];
    if ([_session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [_session setSessionPreset:AVCaptureSessionPreset640x480];
    }
    
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *d in devices) {
        if (d.position == AVCaptureDevicePositionBack && [d hasMediaType:AVMediaTypeVideo]) {
            videoDevice = d;
            break;
        }
    }
    
    NSError *err;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput
                                        deviceInputWithDevice:videoDevice error:&err];
    [_session addInput:videoInput];
    
    captureQueue = dispatch_queue_create("com.jgundersen.captureProcessingQueue", NULL);
    
    AVCaptureDevice *mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:mic error:&err];
    if (err) {
        NSLog(@"Video Device Error %@", [err localizedDescription]);
    }
    [_session addInput:audioDeviceInput];
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:captureQueue];
    [_session addOutput:audioOutput];
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    [videoOutput
     setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey :
                            @(kCVPixelFormatType_32BGRA)}];
    
    [videoOutput setSampleBufferDelegate:self queue:captureQueue];
    
    [_session addOutput:videoOutput];
    
    AVCaptureMetadataOutput *metaDataOutput = [[AVCaptureMetadataOutput alloc] init];
    faceDetectQueue = dispatch_queue_create("com.jgundersen.metadataProcessingQueue", NULL);
    [metaDataOutput setMetadataObjectsDelegate:self queue:faceDetectQueue];
    
    if ([_session canAddOutput:metaDataOutput]) {
        [_session addOutput:metaDataOutput];
    } else {
        NSLog(@"Can't add metadata output");
    }
    [metaDataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeFace]];
    NSLog(@"Available metadata object types - %@", metaDataOutput.availableMetadataObjectTypes);
    
    [_session commitConfiguration];
    [_session startRunning];
    
    _perlin = [CZGPerlinGenerator perlinGenerator];
    _perlin.zoom = 100;
    
    _isWriting = NO;

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    NSString *outputClass = NSStringFromClass([captureOutput class]);
    if ([outputClass isEqualToString:@"AVCaptureAudioDataOutput"]) {
        if (_isWriting &&
            _assetWriterAudioInput.isReadyForMoreMediaData) {
            BOOL succ = [_assetWriterAudioInput
                         appendSampleBuffer:sampleBuffer];
            if (!succ) {
                NSLog(@"audio buffer not appended");
            }
        }
    } else {
        CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
            image = [image imageByApplyingTransform:CGAffineTransformMakeRotation(M_PI)];
            image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(640.0, 480.0)];
        }
        
//        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
//            image = [image imageByApplyingTransform:CGAffineTransformMakeRotation(M_PI)];
//            image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(640.0, 480.0)];
//        }
//        

        image = [self oldTimey:image];
        
        
      
        currentSampleTime =
        CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
        
        if (_isWriting &&
            _assetWriterPixelBufferInput.assetWriterInput.isReadyForMoreMediaData) {
            
            CVPixelBufferRef newPixelBuffer = NULL;
            CVPixelBufferPoolCreatePixelBuffer(NULL,
                                               [_assetWriterPixelBufferInput pixelBufferPool],
                                               &newPixelBuffer);
            
            [_coreImageContext render:image toCVPixelBuffer:newPixelBuffer bounds:CGRectMake(0, 0, 640, 480) colorSpace:NULL];
           
            BOOL success = [_assetWriterPixelBufferInput
                            appendPixelBuffer:newPixelBuffer
                            withPresentationTime:currentSampleTime];
            
            if (!success) {
                NSLog(@"Pixel Buffer not appended");
            }
            
            CVPixelBufferRelease(newPixelBuffer);
        }
        
        
        [_coreImageContext drawImage:image inRect:[image extent] fromRect:[image extent]];
        [_context presentRenderbuffer:GL_RENDERBUFFER ];
    }

}



    



-(CIImage *)oldTimey:(CIImage *)inputImage {
    CFAbsoluteTime timeNow = CFAbsoluteTimeGetCurrent();
    
    float first = [_perlin perlinNoiseX:sin(timeNow) * 1000.0
                                      y:10.0 z:10.0 t:10.0];
    float second = [_perlin perlinNoiseX:cos(timeNow) * 1000.0
                                       y:105.0 z:10.0 t:10.0];
    float third = [_perlin perlinNoiseX:sin(timeNow) * 1000.0
                                      y:200.0 z:10.0 t:10.0];
    
    CIFilter *blackandwhite = [CIFilter
                               filterWithName:@"CIColorControls"];
    [blackandwhite setValue:@0.1f forKey:@"inputSaturation"];
    [blackandwhite setValue:@(first * 0.05)
                     forKey:@"inputBrightness"];
    [blackandwhite setValue:inputImage forKey:kCIInputImageKey];
    CIFilter *vignette = [CIFilter
                          filterWithName:@"CIVignette"];
    [vignette setValue:blackandwhite.outputImage
                forKey:kCIInputImageKey];
    [vignette setValue:@10 forKey:@"inputRadius"];
    [vignette setValue:@(third + 2) forKey:@"inputIntensity"];
	
    CGAffineTransform transForm =
    CGAffineTransformMakeTranslation(first * 1.0,
                                     1.0 + (second * 10));
    CIImage *returnImage = [vignette.outputImage
                            imageByApplyingTransform:transForm];
    
    return returnImage;
}

- (NSURL *)movieURL {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *urlSting = [tempDir stringByAppendingPathComponent:@"tmpMov.mov"];
    return [NSURL fileURLWithPath:urlSting];
}

- (void)checkForAndDeleteFile {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL exist = [fileManager fileExistsAtPath:[self movieURL].path];
    NSError *error;
    if (exist) {
        [fileManager removeItemAtURL:[self movieURL] error:&error];
        NSLog(@"file deleted");
        if (error) {
            NSLog(@"file remove Error:%@", error.localizedDescription);
        }
    }else {
        NSLog(@"no file by that name");
    }
    
}

- (void)createWriter {
    [self checkForAndDeleteFile];
    
    NSError *error;
    _assetWriter = [[AVAssetWriter alloc]initWithURL:[self movieURL] fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        NSLog(@"Couldn't create writer: %@", error.localizedDescription);
        return;
    }

    NSDictionary *outPutSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                     AVVideoWidthKey: @640,
                                     AVVideoHeightKey: @480};
    AVAssetWriterInput *assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outPutSettings];
    
    assetWriterVideoInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *sourcePixelBufferAttributesDictionary = @{
                                                            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                                            (id)kCVPixelBufferWidthKey: @640,
                                                            (id)kCVPixelBufferHeightKey: @480};
    _assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:assetWriterVideoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    if ([_assetWriter canAddInput:assetWriterVideoInput]) {
        [_assetWriter addInput:assetWriterVideoInput];
    }else {
        NSLog(@"Can't add video writer input :%@", assetWriterVideoInput);
    }

    _assetWriterAudioInput = [AVAssetWriterInput
                              assetWriterInputWithMediaType:AVMediaTypeAudio
                              outputSettings:nil];
    if ([_assetWriter canAddInput:_assetWriterAudioInput]) {
        [_assetWriter addInput:_assetWriterAudioInput];
        _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    }

}

- (IBAction)record:(id)sender {
    
    UIButton *button = (UIButton *)sender;
    if (!_isWriting) {
        [self createWriter];
        _isWriting = YES;
        [button setTitle:@"Stop" forState:UIControlStateNormal];
        [_assetWriter startWriting];
        [_assetWriter startSessionAtSourceTime:currentSampleTime];
    }else {
        _isWriting = NO;
        [button setTitle:@"Record" forState:UIControlStateNormal];
        [_assetWriter finishWritingWithCompletionHandler:^{
            
            [self saveMovieToCameraRoll];
        }];
    }
    
}

- (void)saveMovieToCameraRoll {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc]init];
    [library writeVideoAtPathToSavedPhotosAlbum:[self movieURL] completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"Error:%@", [error localizedDescription]);
        }else {
            [self checkForAndDeleteFile];
            NSLog(@"Finished saving");
        }
    }];
}


- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}


@end





















