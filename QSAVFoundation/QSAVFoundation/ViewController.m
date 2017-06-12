//
//  ViewController.m
//  QSAVFoundation
//
//  Created by Bruce on 2017/6/7.
//  Copyright © 2017年 张水生. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
@interface ViewController ()<AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong)AVCaptureSession             *captureSession;
@property (nonatomic, weak)AVCaptureVideoPreviewLayer   *previewLayer;
@property (nonatomic, weak) AVCaptureDeviceInput              *captureInput;
@property (nonatomic, weak) AVCaptureStillImageOutput                 *captureOutput;

@property (nonatomic, strong)UIView                     *cameraView;
@property (nonatomic, strong)dispatch_queue_t           viewQuewe;

@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *switchCamerasButton;

@property (nonatomic, strong) NSString *adjustingExposureContext;

@property (nonatomic, strong) UIImageView *focusMarker;
@property (nonatomic, strong) UIImageView *exposureMarker;
@property (nonatomic, strong) UIImageView *resetMarker;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.view addSubview:self.cameraView];
    [self setCaptureSession];
    [self startPreview];
    [self startSession];
    
    [self.cameraView addSubview:self.captureButton];
    [self.cameraView addSubview:self.switchCamerasButton];
    _adjustingExposureContext = @"";
    
    [self.view addSubview:self.focusMarker];
}

#pragma mark - 回话相关
/**
 创建回话
 */
- (void)setCaptureSession{
    // 创建回话
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    self.captureSession = captureSession;
    // 获取设备
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
//    camera.position = AVCaptureDevicePositionFront;
//    // 设置输入
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
    if (input && [captureSession canAddInput:input]) {
        [captureSession addInput:input];
        self.captureInput = input;
    }else{
        NSLog(@"%@",error);
    }
    
    // 设置输出
    AVCaptureStillImageOutput *output = [[AVCaptureStillImageOutput alloc] init];
    output.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    if (output && [captureSession canAddOutput:output]) {
        [captureSession addOutput:output];
        self.captureOutput = output;
    }else{
        NSLog(@"%@",error);
    }

}

/**
 创建回话预览
 */
- (void)startPreview{
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    previewLayer.frame = self.cameraView.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.cameraView.layer addSublayer:previewLayer];
    
    // add gesture for focus and exposure
    UITapGestureRecognizer *tapForFocus = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(toFocus:)];
    tapForFocus.numberOfTapsRequired = 1;
    tapForFocus.numberOfTouchesRequired = 1;
    
    UITapGestureRecognizer *tapForExposure = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(toExpose:)];
    tapForExposure.numberOfTapsRequired = 2;
    tapForExposure.numberOfTouchesRequired = 1;
    
    UITapGestureRecognizer *tapFoReset = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(resetFocusAndExposure)];
    tapFoReset.numberOfTapsRequired = 2;
    tapFoReset.numberOfTouchesRequired = 2;
    
    [self.cameraView addGestureRecognizer:tapForFocus];
    [self.cameraView addGestureRecognizer:tapForExposure];
    [self.cameraView addGestureRecognizer:tapFoReset];
    [tapForFocus requireGestureRecognizerToFail:tapForExposure];

}

- (void)startSession{
    if (!self.captureSession.isRunning) {
        dispatch_async(self.viewQuewe, ^{
            [self.captureSession startRunning];
        });
    }
}

- (void)stopSession{
    if (self.captureSession.isRunning) {
        dispatch_async(self.viewQuewe, ^{
            [self.captureSession stopRunning];
        });
    }
}


- (dispatch_queue_t)viewQuewe{
    if (!_viewQuewe) {
        _viewQuewe = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    return _viewQuewe;
}

#pragma  mark - Camera Operation Method

- (void)switchCameras:(UIButton *)sender{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    if (devices.count < 1) {
        return;
    }
    AVCaptureDevicePosition newPosition;
    if (self.captureInput.device.position == AVCaptureDevicePositionFront) {
        newPosition = AVCaptureDevicePositionBack;
    }else{
         newPosition = AVCaptureDevicePositionFront;
    }
    AVCaptureDevice *newDevice;
    for (AVCaptureDevice *device in devices) {
        if (device.position == newPosition) {
            newDevice = device;
        }
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:newDevice error:&error];
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.captureInput];
    if (input && [self.captureSession canAddInput:input]) {
        [self.captureSession addInput:input];
        self.captureInput = input;
    }else{
         [self.captureSession addInput:self.captureInput];
    }
    [self.captureSession commitConfiguration];
    
}

// 点击拍照
- (void)captureAction:(UIButton *)sender{
    AVCaptureConnection *connection = [self.captureOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = [self currentVideoOrientation];
    }
    [self.captureOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            [self savePhotoToLibrary:image];
        }
    }];
}

// 获取的图片保存的照片库
- (void)savePhotoToLibrary:(UIImage *)image{
    PHPhotoLibrary * phlibary = [PHPhotoLibrary sharedPhotoLibrary];
    [phlibary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
        }
    }];
}

- (AVCaptureVideoOrientation)currentVideoOrientation{
    AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
    switch (UIDevice.currentDevice.orientation) {
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationLandscapeLeft:
             orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            break;
    }
    return orientation;
}


/**
 聚焦
 */

- (void)focusAtPoint:(CGPoint) point{
    AVCaptureDevice *device = self.captureInput.device;
    if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        @try {
            [device lockForConfiguration:nil];
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        } @catch (NSException *exception) {
            
        } @finally {
            
        }
        
    }
    
}
- (void)toFocus:(UIGestureRecognizer *)gesture{
    if (self.captureInput.device.isFocusPointOfInterestSupported){
        // 获取点击的位置
        CGPoint ponit = [gesture locationInView:self.cameraView];
        // 将点击的位置左边转化为设备的坐标系统位置
        CGPoint pointOfInterest = [self.previewLayer captureDevicePointOfInterestForPoint:ponit];
        [self showMarkerAtPoint:ponit andMarker:self.focusMarker];
        [self focusAtPoint:pointOfInterest];
        
    }
}


/**
 曝光处理
 */
- (void)ExposureAtPoint:(CGPoint)point{
    AVCaptureDevice *device = self.captureInput.device;
    if (device.isExposurePointOfInterestSupported && [device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
        @try {
            [device lockForConfiguration:nil];
            device.exposurePointOfInterest = point;
            device.exposureMode = AVCaptureExposureModeAutoExpose;
            if ([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
                [device addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:&_adjustingExposureContext];
                
                [device unlockForConfiguration];
            }
            
        } @catch (NSException *exception) {
            
        } @finally {
            
        }
    }
}


/**
 监听adjustingExposure，处理逻辑
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if (context == &_adjustingExposureContext) {
        AVCaptureDevice *device = (AVCaptureDevice *)object;
        if (!device.isAdjustingExposure && [device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            [object removeObserver:self forKeyPath:@"adjustingExposure"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [device lockForConfiguration:nil];
                device.exposureMode = AVCaptureExposureModeLocked;
                [device unlockForConfiguration];
            });
        }else{
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
    }
}

- (void)toExpose:(UIGestureRecognizer *)gesture{
    if (self.captureInput.device.isExposurePointOfInterestSupported){
        // 获取点击的位置
        CGPoint ponit = [gesture locationInView:self.cameraView];
        // 将点击的位置左边转化为设备的坐标系统位置
        CGPoint pointOfInterest = [self.previewLayer captureDevicePointOfInterestForPoint:ponit];
        
        [self focusAtPoint:pointOfInterest];
        
    }
}

/**
 重置聚焦和曝光
 */
- (void)resetFocusAndExposure{
    AVCaptureDevice *device = self.captureInput.device;
    AVCaptureFocusMode      focusMode = device.focusMode;
    AVCaptureExposureMode   exposureMode = device.exposureMode;
    BOOL canResetFocus = device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode];
    BOOL canResetExposure = device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode];
    CGPoint center = CGPointMake(.5, .5);
    
    @try {
        [device lockForConfiguration:nil];
        if (canResetFocus) {
            device.focusMode = focusMode;
            device.focusPointOfInterest = center;
        }
        if (canResetExposure) {
            device.exposureMode = exposureMode;
            device.focusPointOfInterest = center;
        }
        [device unlockForConfiguration];
        
    } @catch (NSException *exception) {
        NSLog(@"Error resetting focus & exposure: \(error)");
    } @finally {
        
    }
    
}

- (void)showMarkerAtPoint:(CGPoint)point andMarker:(UIView *)marker{
    marker.center = point;
    marker.hidden = NO;
    [UIView animateWithDuration:.15 animations:^{
        marker.layer.transform = CATransform3DMakeScale(.5, .5, 1.0);
    } completion:^(BOOL finished) {
        CGFloat delay = .5;
        CGFloat popTime = DISPATCH_TIME_NOW + delay;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(popTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            marker.hidden = YES;
            marker.transform = CGAffineTransformIdentity;
        });
    }];
}

#pragma mark - property
- (UIView *)cameraView{
    if (!_cameraView) {
        _cameraView = [[UIView alloc]initWithFrame:self.view.bounds];
        _cameraView.backgroundColor = [UIColor blackColor];
    }
    return _cameraView;
}

- (UIImageView *)focusMarker{
    if (!_focusMarker) {
        _focusMarker = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"Focus_Point"]];
        _focusMarker.hidden = YES;
    }
    return _focusMarker;
}

- (UIButton *)captureButton{
    if (!_captureButton) {
        _captureButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_captureButton setImage:[UIImage imageNamed:@"Capture_Butt"] forState:UIControlStateNormal];
        _captureButton.backgroundColor = [UIColor clearColor];
        CGFloat height = [UIScreen mainScreen].bounds.size.height;
        CGFloat width = [UIScreen mainScreen].bounds.size.width;
        _captureButton.frame = CGRectMake((width - 40)/2, height - 80, 40, 40);
        [_captureButton addTarget:self action:@selector(captureAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _captureButton;
}

- (UIButton *)switchCamerasButton{
    if (!_switchCamerasButton) {
        _switchCamerasButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_switchCamerasButton setImage:[UIImage imageNamed:@"Camera_Icon"] forState:UIControlStateNormal];
        _switchCamerasButton.backgroundColor = [UIColor clearColor];
        CGFloat width = [UIScreen mainScreen].bounds.size.width;
        _switchCamerasButton.frame = CGRectMake(width - 80, 40, 40, 40);
        [_switchCamerasButton addTarget:self action:@selector(switchCameras:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchCamerasButton;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
