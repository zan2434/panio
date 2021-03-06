//
//  RecordVideo.m
//  VideoPlayRecord
//
//  Created by Abdul Azeem Khan on 5/9/12.
//  Copyright (c) 2012 DataInvent. All rights reserved.
//

#import "RecordVideo.h"
#import <CoreMotion/CoreMotion.h>
#import <AVFoundation/AVFoundation.h>

CMMotionManager *motionManager;
CMAttitude *referenceAttitude;
NSMutableArray *gyroDataStream;
NSMutableData *responseData;
AVCaptureSession *captureSession;
AVCaptureMovieFileOutput *movieFileOutput;

@implementation RecordVideo
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

//#pragma mark - View lifecycle

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


// For responding to the user tapping Cancel.
- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
    
    [self dismissModalViewControllerAnimated: YES];
}
- (IBAction)RecordAndPlay:(id)sender {
//    [self startCameraControllerFromViewController: self
//                                    usingDelegate: self];
//
    [self startAVFMovieCapture:self];
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(onTick:)
                                   userInfo:nil
                                    repeats:NO];
}

-(void)onTick:(NSTimer *)timer {
    motionManager = [[CMMotionManager alloc] init];
    referenceAttitude = nil;
//    NSMutableArray *gyroDataStream = [NSMutableArray arrayWithObjects:@[@0,@0,@0], nil];
    gyroDataStream = [[NSMutableArray alloc] init];

    //Gyroscope
    if([motionManager isGyroAvailable])
    {
        /* Start the gyroscope if it is not active already */
        if([motionManager isGyroActive] == NO)
        {
            /* Update us 2 times a second */
            [motionManager setGyroUpdateInterval:1.0f / 30.0f];
            
            /* Add on a handler block object */
            
            /* Receive the gyroscope data on this block */
            [motionManager startGyroUpdatesToQueue:[NSOperationQueue mainQueue]
                                            withHandler:^(CMGyroData *gyroData, NSError *error)
             {
                 NSArray *gyroAxisData = @[
                                           [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]* 1000.0],
                                           [NSNumber numberWithDouble:gyroData.rotationRate.x],
                                           [NSNumber numberWithDouble:gyroData.rotationRate.y],
                                           [NSNumber numberWithDouble:gyroData.rotationRate.z]
                                           ];
                 [gyroDataStream addObject:gyroAxisData];
                 NSLog( @"%@",[[gyroDataStream lastObject] componentsJoinedByString:@", "]);

//                 NSLog(@"Gyroscope Available!");
             }];

        }
    }
    else
    {
        NSLog(@"Gyroscope not Available!");
    }
}

- (void) stopAVFRecording{
    [motionManager stopGyroUpdates];
    [self addGyroMetadata];
    [movieFileOutput stopRecording];
    NSLog(@"saved metadata %@", movieFileOutput.metadata[0]);
    //NSLog( @"%@",[gyroDataStream componentsJoinedByString:@" FINAL, "]);
}

- (void) addGyroMetadata{
    NSArray *existingMetadataArray = movieFileOutput.metadata;
    NSMutableArray *newMetadataArray = nil;
    if (existingMetadataArray) {
        newMetadataArray = [existingMetadataArray mutableCopy];
    }
    else {
        newMetadataArray = [[NSMutableArray alloc] init];
    }
    
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.keySpace = AVMetadataKeySpaceCommon;
    item.key = AVMetadataCommonKeyDescription;
    
    item.value = gyroDataStream;
    
    [newMetadataArray addObject:item];
    
    movieFileOutput.metadata = newMetadataArray;
}

- (BOOL) startAVFMovieCapture: (UIViewController*) controller{
    captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    AVCaptureDeviceInput *cameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:cameraDevice error:&error];

    if ([captureSession canAddInput:cameraDeviceInput]) {
        [captureSession addInput:cameraDeviceInput];
    }
    
    movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    if([captureSession canAddOutput:movieFileOutput]){
        [captureSession addOutput:movieFileOutput];
    }
    [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    
    [captureSession commitConfiguration];

    //    NSURL *outputURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    
    //Create temporary URL to record to
    NSString *outputPath = [[NSString alloc] initWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"];
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath])
    {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO)
        {
            NSLog(@"some error occurred when checking for file at path");
        }
    }
    //Start recording
    
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    
    previewLayer.contentsGravity = kCAGravityResizeAspectFill;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    UIView *previewView = [controller view];
    previewLayer.frame = previewView.bounds;
    [previewView.layer addSublayer:previewLayer];
    
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [cancelButton addTarget:self action:@selector(stopAVFRecording) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton setFrame:CGRectMake(previewView.bounds.size.width/2, previewView.bounds.size.height-100, 40, 40)];
    [cancelButton setTitle:@"stop" forState:UIControlStateNormal];
    [previewView addSubview:cancelButton];
    
    [captureSession startRunning];
    [movieFileOutput startRecordingToOutputFileURL:outputURL recordingDelegate:self];

}

- (void) captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"started recording brah!");
}
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray *)connections
                error:(NSError *)error
{
    
    NSLog(@"didFinishRecordingToOutputFileAtURL - enter");
    
    BOOL RecordedSuccessfully = YES;
    if ([error code] != noErr)
    {
        // A problem occurred: Find out if the recording was successful.
        id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
        if (value)
        {
            RecordedSuccessfully = [value boolValue];
        }
    }
    if (RecordedSuccessfully)
    {
        //----- RECORDED SUCESSFULLY -----
        NSLog(@"didFinishRecordingToOutputFileAtURL - success");
        
//        NSLog( @"%@",[gyroDataStream componentsJoinedByString:@" FINAL, "]);
//        NSLog();
        
        // read metadata
        NSLog(@"video has %@", outputFileURL.path);
        AVAsset *videoAsset = [AVAsset assetWithURL:outputFileURL];
        NSLog(@"Loading metadata...");
        NSArray *keys = [[NSArray alloc] initWithObjects:@"commonMetadata", nil];
        NSMutableArray *metadata = [[NSMutableArray alloc] init];
        [videoAsset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
            
            [metadata removeAllObjects];
            for (NSString *format in [videoAsset availableMetadataFormats])
            {
                [metadata addObjectsFromArray:[videoAsset metadataForFormat:format]];
                NSLog(@"Printing metadata-%@",metadata);
            }
            
            
        }];
        //end metadata reading
        
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputFileURL])
        {
            [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                        completionBlock:^(NSURL *assetURL, NSError *error)
             {
                 if (error)
                 {
                     NSLog(@"drastic error");
                 }
             }];
        }
        
    }
}

- (BOOL) startCameraControllerFromViewController: (UIViewController*) controller
                                   usingDelegate: (id <UIImagePickerControllerDelegate,
                                                   UINavigationControllerDelegate>) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    // Displays a control that allows the user to choose movie capture
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    
    cameraUI.delegate = delegate;
    
    [controller presentModalViewController: cameraUI animated: YES];
    return YES;
}


// For responding to the user accepting a newly-captured picture or movie
- (void) imagePickerController: (UIImagePickerController *) picker
 didFinishPickingMediaWithInfo: (NSDictionary *) info {
    
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    [self dismissModalViewControllerAnimated:NO];
    NSLog(@"sending videoooo");
    
    // Handle a movie capture
    if (CFStringCompare ((__bridge_retained CFStringRef) mediaType, kUTTypeMovie, 0)
        == kCFCompareEqualTo) {
        
        NSString *moviePath = [[info objectForKey:
                                UIImagePickerControllerMediaURL] path];
        NSURL *movieURL = [info objectForKey:UIImagePickerControllerMediaURL];
        NSData *webData = [NSData dataWithContentsOfURL:movieURL];
//        [self post:webData];
//        [self uploadvideo:webData];
        NSURLRequest *urlRequest = [self postRequestWithURL:@"http://ec2-54-187-10-230.us-west-2.compute.amazonaws.com:5000/classify_upload"
                                                       data:webData
                                                   fileName:@"clip.mov"];
        
        NSURLConnection *uploadConnection =[[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
        
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (moviePath)) {
            UISaveVideoAtPathToSavedPhotosAlbum (moviePath,self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
        
    }
    [motionManager stopGyroUpdates];
    NSError * error;
//    NSLog( @"%@",[gyroDataStream componentsJoinedByString:@" FINAL, "]);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:gyroDataStream options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
}

- (void)video:(NSString*)videoPath didFinishSavingWithError:(NSError*)error contextInfo:(void*)contextInfo
{
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"  delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil, nil];
        [alert show];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"  delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil];
        [alert show];
        
    }
}
- (NSData *)generatePostDataForData:(NSData *)uploadData
{
    // Generate the post header:
    NSString *post = [NSString stringWithCString:"--AaB03x\r\nContent-Disposition: form-data; name=\"upload[file]\"; filename=\"somefile\"\r\nContent-Type: application/octet-stream\r\nContent-Transfer-Encoding: binary\r\n\r\n" encoding:NSASCIIStringEncoding];
    
    // Get the post header int ASCII format:
    NSData *postHeaderData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    
    // Generate the mutable data variable:
    NSMutableData *postData = [[NSMutableData alloc] initWithLength:[postHeaderData length] ];
    [postData setData:postHeaderData];
    
    // Add the image:
    [postData appendData: uploadData];
    
    // Add the closing boundry:
    [postData appendData: [@"\r\n--AaB03x--" dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
    
    // Return the post data:
    return postData;
}

- (void)post:(NSData *)fileData
{
    
    NSLog(@"POSTING");
    
    // Generate the postdata:
    NSData *postData = [self generatePostDataForData: fileData];
    NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
    
    // Setup the request:
    NSMutableURLRequest *uploadRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://ec2-54-187-10-230.us-west-2.compute.amazonaws.com:5000/classify_upload"] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 1e4 ];
    [uploadRequest setHTTPMethod:@"POST"];
    [uploadRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [uploadRequest setValue:@"multipart/form-data; boundary=AaB03x" forHTTPHeaderField:@"Content-Type"];
    [uploadRequest setHTTPBody:postData];
    
    responseData = [[NSMutableData alloc] init];
    
    // Execute the reqest:
    NSURLConnection *conn=[[NSURLConnection alloc] initWithRequest:uploadRequest delegate:self];
    if (conn)
    {
        // Connection succeeded (even if a 404 or other non-200 range was returned).
        NSLog(@"sucess");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Got Server Response" message:@"Success" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
    else
    {
        // Connection failed (cannot reach server).
        NSLog(@"fail");
    }
    
}

-(void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [responseData appendData:data];
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding];
    NSLog(@"Got server response %@", responseString);
//    NSLog(responseString);
}

- (void)uploadvideo:(NSData *)data{
    
//    NSString *strurl=[NSString stringWithFormat:@"%@",];
    
//    NSString *url=[[NSString alloc]initWithFormat:@"video_upload.php?user_id=%@&node_id=%@",appDele.UserId,appDele.strProductId];
    
    
//    NSString *urlString =[NSString stringWithFormat:@"%@%@",strurl,url] ;
//    NSLog(@"%@",urlString);
    
//    NSString *encodedString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    // setting up the request object now
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"http://ec2-54-187-10-230.us-west-2.compute.amazonaws.com:5000/classify_upload"]];
    [request setHTTPMethod:@"POST"];
    [request setTimeoutInterval:10000000];
    
    
    
    // NSInputStream *videoStream = [[[NSInputStream alloc] initWithData:data1] autorelease];
    // [request setHTTPBodyStream:videoStream];
    
    NSString *boundary = [NSString stringWithFormat:@"---------------------------14737809831466499882746641449"];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    /*
     now lets create the body of the post
     */
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"filename\"; filename=\"New.mp4\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    // NSLog(@"%@New.jpg",appDelegate.MemberId);
    [body appendData:[[NSString stringWithFormat:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    //  [body appendData:data1.length];
//    [body appendData:[NSData dataWithData:data1]];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // setting the body of the post to the reqeust
    
    [request setHTTPBody:body];
    
    // now lets make the connection to the web
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
    NSLog(@"%@",returnString);
}

-(NSURLRequest *)postRequestWithURL: (NSString *)url
                               data: (NSData *)data
                           fileName: (NSString*)fileName
{
    
    // from http://www.cocoadev.com/index.pl?HTTPFileUpload
    
    //NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] init];
    [urlRequest setURL:[NSURL URLWithString:url]];
//    [urlRequest setURL:url];
    
    [urlRequest setHTTPMethod:@"POST"];
    
    NSString *myboundary = [NSString stringWithString:@"---------------------------14737809831466499882746641449"];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",myboundary];
    [urlRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    
    //[urlRequest addValue: [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundry] forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData *postData = [NSMutableData data]; //[NSMutableData dataWithCapacity:[data length] + 512];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"imagefile\"; filename=\"%@\"\r\n", fileName]dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[NSData dataWithData:data]];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [urlRequest setHTTPBody:postData];
    return urlRequest;
}

@end
