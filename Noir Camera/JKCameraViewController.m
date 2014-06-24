//
//  JKCameraViewController.m
//  Noir Camera
//
//  Created by Jay on 5/3/14.
//  Copyright (c) 2014 Zihae. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "JKCameraViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <GLKit/GLKit.h>
#import <MobileCoreServices/MobileCoreServices.h>


@interface JKCameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>
{
    AVCaptureSession *_session;
    dispatch_queue_t captureQueue;
    
    CIContext *_coreImageContext;
    EAGLContext *_context;
    
    __weak IBOutlet GLKView *_glView;
    
}
@end

@implementation JKCameraViewController

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
    _glView.contentScaleFactor = 320.0/screenWidth;
    _coreImageContext = [CIContext contextWithEAGLContext:_context];
    
    
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
    
    NSError *error;
    AVCaptureDeviceInput *videoInPut = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    [_session addInput:videoInPut];
    
    AVCaptureVideoDataOutput *videoOutPut = [[AVCaptureVideoDataOutput alloc]init];
    [videoOutPut setAlwaysDiscardsLateVideoFrames:YES];
    
    [videoOutPut setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
    
    captureQueue = dispatch_queue_create("com.jgundersen.captureProcessingQueue", NULL);
    [videoOutPut setSampleBufferDelegate:self queue:captureQueue];
    
    [_session addOutput:videoOutPut];
    [_session commitConfiguration];
    [_session startRunning];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    [_coreImageContext drawImage:image inRect:[image extent] fromRect:[image extent]];
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
}


@end









