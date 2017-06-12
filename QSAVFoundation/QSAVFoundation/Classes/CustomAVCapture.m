//
//  CustomAVCapture.m
//  QSAVFoundation
//
//  Created by Bruce on 2017/6/7.
//  Copyright © 2017年 张水生. All rights reserved.
//

#import "CustomAVCapture.h"
#import "AVFoundation/AVFoundation.h"
@interface CustomAVCapture()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong)AVCaptureSession *captureSession;

@end

@implementation CustomAVCapture

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}
- (void)configCaptureInfo:(NSString *)mediaType{
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:mediaType];
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (input) {
        [captureSession addInput:input];
    }
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc]init];
    [captureSession addOutput:output];
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:videoDataOutputQueue];
    [captureSession addOutput:output];

}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    NSLog(@"%@",sampleBuffer);
}

@end
