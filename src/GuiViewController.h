//
//  GuiViewController.h
//  TerryFaceSubstitution
//
//  Created by Terry Bu on 3/6/15.
//
//

#ifndef __TerryFaceSubstitution__GuiViewController__
#define __TerryFaceSubstitution__GuiViewController__

#include <stdio.h>

#endif /* defined(__TerryFaceSubstitution__GuiViewController__) */

#import <UIKit/UIKit.h>
#import "SVProgressHUD.h"
#include "ofApp.h"

typedef enum : NSUInteger {
    BeardImage,
    WomanImage,
    AvatarImage,
} SubImageType;


@interface GuiViewController : UIViewController<UIImagePickerControllerDelegate, UINavigationControllerDelegate>{
    ofApp *myApp;
    UIImage *pickedImage;
    ofImage img;
    UIImage *maskedImage;
}

- (void)openCamera;

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *makeVideoAndSaveButton;
@property (weak, nonatomic) IBOutlet UILabel *processingStatusLabel;

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property SubImageType faceSelectionControl;

- (IBAction)makeVideoAndSave;
- (IBAction)segmentSwitched:(id)sender;


@end