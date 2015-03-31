//
//  GuiViewController.cpp
//  TerryFaceSubstitution
//
//  Created by Terry Bu on 3/6/15.
//
//

#include "GuiViewController.h"
#include "ofxiOSExtras.h"
#include <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "CEMovieMaker.h"
#import <MediaPlayer/MediaPlayer.h>

@interface GuiViewController () {
    UIImage *thumbnail;
    Float64 limit;
    NSURL *videoCompletedFileURL;
    CEMovieMaker *movieMaker;
}

@property (assign) SystemSoundID sound;

@end

@implementation GuiViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    myApp = (ofApp *)ofGetAppPtr();
    
    self.statusLabel.hidden = TRUE;
    self.makeVideoAndSaveButton.hidden = TRUE;
    self.processingStatusLabel.text = @"";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIImagePickerControllerDelegate

- (void)openCamera{
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]){
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc]init];
        [imagePickerController setSourceType:UIImagePickerControllerSourceTypeCamera];
        [imagePickerController setAllowsEditing:NO];
        [imagePickerController setDelegate:self];
        [imagePickerController setEditing:NO];
        [self presentViewController:imagePickerController animated:YES completion:nil];
    }
    else{
        NSLog(@"camera invalid");
    }
}


- (IBAction) openPhotoLibraryToSelectVideo{
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc]init];
        [imagePickerController setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        imagePickerController.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil]; //import mobile core services
        [imagePickerController setAllowsEditing:NO];
        [imagePickerController setDelegate:self];
        
        [self presentViewController:imagePickerController animated:YES completion:nil];
    }
    else{
        NSLog(@"photo library invalid");
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    [self dismissViewControllerAnimated:YES completion:^{
        
        [SVProgressHUD show];
        if (CFStringCompare ((__bridge_retained CFStringRef)mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
            NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            //import <AssetsLibrary> for this
            [library assetForURL:videoURL resultBlock:^(ALAsset *asset) {
                //this is the block to use with your asset
                //whatever you want to perform to your asset, you should do so in this block
                //user might have to say yes to permission. If denied, failure block will get called
                
                AVAsset *avAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
                AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:avAsset];
                imageGenerator.appliesPreferredTrackTransform = YES;
                imageGenerator.requestedTimeToleranceAfter =  kCMTimeZero;
                imageGenerator.requestedTimeToleranceBefore =  kCMTimeZero;
                int FPS = 25;
                limit = CMTimeGetSeconds(avAsset.duration) *  FPS;
                for (Float64 i = 0; i < limit; i++){
                    @autoreleasepool {
                        CMTime time = CMTimeMake(i, FPS);
                        NSError *err;
                        CMTime actualTime;
                        CGImageRef image = [imageGenerator copyCGImageAtTime:time actualTime:&actualTime error:&err];
                        UIImage *extractedFrame = [[UIImage alloc] initWithCGImage:image];
                        UIImage *maskImage = [self getMaskedImage: extractedFrame];
                        [self saveImage: maskImage index:i];
                        CGImageRelease(image);
                        if (i == 0)
                            thumbnail = maskImage;
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.imageView.image = thumbnail;
                    NSLog(@"total # of stills: %f", limit);
                    [SVProgressHUD dismiss];
                    self.statusLabel.hidden = NO;
                    self.makeVideoAndSaveButton.hidden = NO;
                    self.statusLabel.text = @"Still Thumbnails Successfuly Generated From Selected Video";
                    [self playBeepSound];
                });
            } failureBlock:nil];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [self dismissViewControllerAnimated:YES completion:nil];
    self.imageView.image = nil;
    myApp->myScene = ready;
}

#pragma mark - Image Conversion
- (UIImage *)getMaskedImage: (UIImage *) unmorphedImage{
    ofxiOSUIImageToOFImage(unmorphedImage, img);
    myApp->maskTakenPhoto(img);
    UIImage *maskImage = [UIImage imageWithCGImage:UIImageFromOFImage(myApp->maskedImage).CGImage];
    return maskImage;
}

- (void) saveImage: (UIImage *) imageToSave index: (int) i {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"frame%d", i]];
    NSLog(@"filePath %@", filePath);
    NSData *data = UIImagePNGRepresentation(imageToSave);
    [data writeToFile:filePath atomically:YES];
    self.processingStatusLabel.text = [NSString stringWithFormat:@"Total frames to process: %d. On Frame #%d", (int) limit, i];
}

UIImage * UIImageFromOFImage( ofImage & img ){
    int width = img.width;
    int height =img.height;
    
    int nrOfColorComponents = 1;
    
    if (img.type == OF_IMAGE_GRAYSCALE) nrOfColorComponents = 1;
    else if (img.type == OF_IMAGE_COLOR) nrOfColorComponents = 3;
    else if (img.type == OF_IMAGE_COLOR_ALPHA) nrOfColorComponents = 4;
    
    int bitsPerColorComponent = 8;
    int rawImageDataLength = width * height * nrOfColorComponents;
    BOOL interpolateAndSmoothPixels = NO;
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGDataProviderRef dataProviderRef;
    CGColorSpaceRef colorSpaceRef;
    CGImageRef imageRef;
    GLubyte *rawImageDataBuffer = img.getPixels();
    dataProviderRef = CGDataProviderCreateWithData(NULL, rawImageDataBuffer, rawImageDataLength, nil);
    colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    imageRef = CGImageCreate(width, height, bitsPerColorComponent, bitsPerColorComponent * nrOfColorComponents, width * nrOfColorComponents, colorSpaceRef, bitmapInfo, dataProviderRef, NULL, interpolateAndSmoothPixels, renderingIntent);
    UIImage * uimg = [UIImage imageWithCGImage:imageRef];
    return uimg;
}



#pragma mark - Stills to Video Conversion, Playing and Saving

- (IBAction) makeVideoAndSave {
    [SVProgressHUD show];
    NSMutableArray *frames = [self loadImagesFromSavedDirectoryIntoArray];
    [self createMovieOutofStillPhotos:frames];
}

- (IBAction)segmentSwitched:(id)sender {
    UISegmentedControl *segmentedControl = (UISegmentedControl *) sender;
    NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
    if (selectedSegment == 0) {
        //Beard
        self.faceSelectionControl = BeardImage;
    }
    else if (selectedSegment == 1){
        //Woman
        self.faceSelectionControl = WomanImage;
    }
    else if (selectedSegment == 2) {
        //Avatar
        self.faceSelectionControl = AvatarImage;
    }
}

- (NSMutableArray *) loadImagesFromSavedDirectoryIntoArray {
    NSMutableArray *frames = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    for (int i=0; i < limit; i++) {
        NSString* filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"frame%d", i]];
        UIImage* image = [UIImage imageWithContentsOfFile:filePath];
        [frames addObject:image];
    }
    
    return frames;
}

- (void) createMovieOutofStillPhotos: (NSMutableArray *) arrayOfFrames {
    UIImage *image = arrayOfFrames[0];
    NSDictionary *settings = [CEMovieMaker videoSettingsWithCodec:AVVideoCodecH264 withWidth:image.size.width andHeight:image.size.height];
    movieMaker = [[CEMovieMaker alloc] initWithSettings:settings];
    [movieMaker createMovieFromImages:[arrayOfFrames copy] withCompletion:^(NSURL *fileURL){
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            self.statusLabel.text = @"A new video was successfully created from our extracted frames";
            [self save:self];
        });
        [self viewMovieAtUrl:fileURL];
        videoCompletedFileURL = fileURL;
    }];
}

- (void)viewMovieAtUrl:(NSURL *)fileURL
{
    MPMoviePlayerViewController *playerController = [[MPMoviePlayerViewController alloc] initWithContentURL:fileURL];
    [playerController.view setFrame:self.view.bounds];
    [self presentMoviePlayerViewControllerAnimated:playerController];
    [playerController.moviePlayer prepareToPlay];
    [playerController.moviePlayer play];
    [self.view addSubview:playerController.view];
}


- (IBAction)save:(id)sender {
    [SVProgressHUD show];
    if (videoCompletedFileURL) {
        UISaveVideoAtPathToSavedPhotosAlbum([videoCompletedFileURL relativePath], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }
}


-(void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    if(error){
        NSLog(@"error logging: %@", error);
        self.statusLabel.text = @"error: saving failed";
    }
    else{
        self.statusLabel.text = @"Saved to Photos Album succeeded";
        [self playBeepSound];
    }
    [[self.statusLabel layer]setCornerRadius:8.0];
    self.statusLabel.hidden = NO;
    
    [SVProgressHUD dismiss];
    UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Saved Video" message:@"Your newly created video got saved to Photos" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alertView show];
}



- (void)finishSaving:(UIImage *)_image didFinishSavingWithError:(NSError*)_error contextInfo:(void *)_contextinfo{
    if(_error){
        NSLog(@"error logging: %@", _error);
        self.statusLabel.text = @"error: saving failed";
    }
    else{
        self.statusLabel.text = @"Saved to Photos Album succeeded";
        [self playBeepSound];
    }
    [[self.statusLabel layer]setCornerRadius:8.0];
    [self.statusLabel setClipsToBounds:YES];
    CATransition *animation = [CATransition animation];
    animation.type = kCATransitionFade;
    animation.duration = 0.4;
    [[self.statusLabel layer]addAnimation:animation forKey:nil];
    
    self.statusLabel.hidden = NO;
    
    [SVProgressHUD dismiss];
}

- (void) playBeepSound {
    NSString *pewPewPath = [[NSBundle mainBundle]
                            pathForResource:@"beep-hightone" ofType:@"aif"];
    NSURL *pewPewURL = [NSURL fileURLWithPath:pewPewPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)pewPewURL, &_sound);
    AudioServicesPlaySystemSound(self.sound);
}



@end
