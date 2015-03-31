#include "ofApp.h"
#include "GuiViewController.h"


GuiViewController *guiViewController;

//--------------------------------------------------------------
void ofApp::setup(){
    ofSetVerticalSync(true);
    ofBackground(0, 0, 0);
    ofEnableSmoothing();
    
    cameraFaceTracker.setup();
    maskFaceTracker.setup();
    cloneReady = false;
    bTakenPhoto = false;
    myScene = ready;
    
    // gui set up
    guiViewController = [[GuiViewController alloc]initWithNibName:@"GuiViewController" bundle:nil];
    [ofxiOSGetGLParentView() addSubview:guiViewController.view];
}

//--------------------------------------------------------------
void ofApp::update(){
    
}

//--------------------------------------------------------------
void ofApp::draw(){
    
}

//--------------------------------------------------------------
void ofApp::exit(){
    
}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){

}

//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void ofApp::touchDoubleTap(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void ofApp::touchCancelled(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void ofApp::lostFocus(){
    
}

//--------------------------------------------------------------
void ofApp::gotFocus(){
    
}

//--------------------------------------------------------------
void ofApp::gotMemoryWarning(){
    
}

//--------------------------------------------------------------
void ofApp::deviceOrientationChanged(int newOrientation){
    
}


#pragma mark Face Substitution Related

void ofApp::setMaskFaceTracker(){
    if(maskImage.isAllocated())
        maskImage.clear();
    if(maskPoints.size() > 0)
        maskPoints.clear();
    maskFaceTracker.setup();
    
    // set mask Image
    //if you drop images in data folder, it will pick these up
    string url;
    if (guiViewController.faceSelectionControl) {
        if (guiViewController.faceSelectionControl == BeardImage) {
            NSLog(@"going with BEARD");
            url =  "beard.jpg";
        }
        else if (guiViewController.faceSelectionControl == WomanImage) {
            NSLog(@"going with WOMAN");
            url = "woman.jpg";
        }
        else if (guiViewController.faceSelectionControl == AvatarImage) {
            NSLog(@"going with AVATAR");
            url = "avatar.jpg";
        }
    }
    else {
        NSLog(@"going with default beard");
        url = "beard.jpg";
    }
    maskImage.loadImage(url);
    
    // setup maskFaceTracker
    if(maskImage.getWidth() > 0){
        maskFaceTracker.update(ofxCv::toCv(maskImage));
        maskPoints = maskFaceTracker.getImagePoints();
        if(!maskFaceTracker.getFound()){
            cout<<"please select good mask image."<<endl;
            setMaskFaceTracker();
        }
    }
}

void ofApp::maskTakenPhoto(ofImage &input){
    
    //Input variable refers to our "just taken photo, your face, from the camera"
    setMaskFaceTracker();
    // change image type. OF_IMAGE_COLOR_ALPHA => OF_IMAGE_COLOR
    if(input.type == OF_IMAGE_COLOR_ALPHA){
        input.setImageType(OF_IMAGE_COLOR);
    }
    
    // resize input image.
    if(input.getWidth() > input.getHeight()){
        input.resize(ofGetWidth(), input.getHeight()*ofGetWidth() /input.getWidth());
    }
    else{
        input.resize(input.getWidth()*ofGetHeight()/input.getHeight(), ofGetHeight());
    }
    
    // set mask Fbo
    ofFbo::Settings settings;
    settings.width = input.getWidth();
    settings.height= input.getHeight();
    maskFbo.allocate(settings);
    cameraFbo.allocate(settings);
    
    //Clone library is responsbile for merging the Mask with the Input
    clone.setup(input.getWidth(), input.getHeight());
    cameraFaceTracker.update(ofxCv::toCv(input));
    cloneReady = cameraFaceTracker.getFound(); //yes if FaceTracker could identify a face from our input
    
    drawMaskOnInput(input);
}

void ofApp::drawMaskOnInput(ofImage &input){
    if(cloneReady){
        //this is the actual MERGING of the images.
        ofMesh cameraMesh = cameraFaceTracker.getImageMesh();
        cameraMesh.clearTexCoords();
        cameraMesh.addTexCoords(maskPoints);
        for(int i=0; i< cameraMesh.getTexCoords().size(); i++) {
            ofVec2f & texCoord = cameraMesh.getTexCoords()[i];
            texCoord.x /= ofNextPow2(maskImage.getWidth());
            texCoord.y /= ofNextPow2(maskImage.getHeight());
        }
        maskFbo.begin();
        ofClear(0, 255);
        cameraMesh.draw();
        maskFbo.end();
        cameraFbo.begin();
        ofClear(0, 255);
        input.getTextureReference().bind();
        maskImage.bind();
        cameraMesh.draw();
        maskImage.unbind();
        cameraFbo.end();
        clone.setStrength(25);
        //original setting was 12 but raising it to 30 really exaggerates the clone, dramatic.
        clone.update(cameraFbo.getTextureReference(), input.getTextureReference(), maskFbo.getTextureReference());
        ofPixels pixels;
        clone.buffer.readToPixels(pixels);
        //at this point, we are done with the merging, and the merged image is now in pixels form.
        //We set it to our ofImage maskedImage property.
        maskedImage.setFromPixels(pixels);
        maskedImage.update();
        
        myScene = preview;
    }
    else{
        maskedImage = input;
    }
}
