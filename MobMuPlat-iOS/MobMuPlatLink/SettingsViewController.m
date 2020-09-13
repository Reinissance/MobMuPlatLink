//
//  SettingsViewController.m
//  MobMuPlat
//
//  Created by Daniel Iglesia on 11/30/12.
//  Copyright (c) 2012 Daniel Iglesia. All rights reserved.
//
//  This object creates the viewcontroller and views when you hit the "info" button on the main screen.
//  It contains 3 buttons at the bottom, to show three subviews
//  -filesView contains a table showing the documents in the Documents directory, selectable to load
//  -audioMIDIView shows some audio and DSP options and lets you select the midi source
//  -consoleView has a TextView to print out PureData console messages (including anything sent to a [print] object in the PD patch)

#import "SettingsViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import "ZipArchive.h"

#import "MMPNetworkingUtils.h"
#import "MMPViewController.h"
#import "AppDelegate.h"

#import "ABLLink.h"
#include "ABLLinkSettingsViewController.h"

#define APP ((AppDelegate *)[[UIApplication sharedApplication] delegate])

@interface SettingsViewController () {
  NSArray *_LANdiniUserArray;
  NSArray *_pingAndConnectUserArray;
  NSTimer *_networkTimer;
  NSString *_LANdiniSyncServerName;
  NSTimer *_updateNetworkLabelTimer;
}
@end


@implementation SettingsViewController {
  BOOL _mmpOrAll, _flipped;
    UIViewController *linkSettings_;
}

static NSString *documentsTableCellIdentifier = @"documentsTableCell";
static NSString *midiTableCellIdentifier = @"midiTableCell";
static NSString *landiniTableCellIdentifier = @"landiniTableCell";
static NSString *pingAndConnectTableCellIdentifier = @"pingAndConnectTableCell";


//what kind of device am I one? iphone 3.5", iphone 4", or ipad
+(MMPDeviceCanvasType)getCanvasType{
  MMPDeviceCanvasType hardwareCanvasType;
  if([[UIDevice currentDevice]userInterfaceIdiom]==UIUserInterfaceIdiomPhone)
  {
    if ([[UIScreen mainScreen] bounds].size.height >= 568)hardwareCanvasType=canvasTypeTallPhone;
    else hardwareCanvasType=canvasTypeWidePhone; //iphone <=4
  }
  else hardwareCanvasType=canvasTypeWideTablet; // iPad
  return hardwareCanvasType;
}

//return a list of items in documents. if argument==NO, get everything, if YES, only get .mmp files
+ (NSMutableArray *)getDocumentsOnlyMMP:(BOOL)onlyMMP{

  NSMutableArray *retval = [[NSMutableArray alloc]init];

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *publicDocumentsDir = [paths objectAtIndex:0];
  NSError *error;
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:publicDocumentsDir error:&error];


  for(NSString* file in files){
    if(!onlyMMP) [retval addObject:file];//everything

    else if ([[file pathExtension] isEqualToString: @"mmp"]) {//just mmp
      [retval addObject:file];
    }
  }
  return retval;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    consoleTextString = @"";
    consoleStringQueue = [[NSMutableArray alloc]init];
  }
  return self;
}

- (void)viewDidLoad{
  [super viewDidLoad];

  /*[[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(checkReach)
                                               name:UIApplicationDidBecomeActiveNotification object:nil];*/

  //ios 7 don't have it go under the nav bar
  if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
    self.edgesForExtendedLayout = UIRectEdgeNone;

  self.view.backgroundColor=[UIColor colorWithRed:.4 green:.4 blue:.4 alpha:1];



  self.navigationItem.title = @"Select Document";
  UIBarButtonItem* doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self
                                                                              action:@selector(done:)];
  self.navigationItem.leftBarButtonItem = doneButton;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reachabilityChanged:)
                                               name:kReachabilityChangedNotification
                                             object:nil];

    #if TARGET_OS_MACCATALYST
    _flipInterfaceButton.hidden = YES;
    #else
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(connectionsChanged:)
                                               name:ABConnectionsChangedNotification
                                             object:nil];
#endif
  //doesn't catch it on creation, so check it now
  [self connectionsChanged:nil];


  //match default pdaudiocontroller settings
  outputChannelCount = 2;

  //allowed sampling rate values for use in the segmented control
  rateValueArray[0]=8000;
  rateValueArray[1]=11025;
  rateValueArray[2]=22050;
  rateValueArray[3]=32000;
  rateValueArray[4]=44100;
  rateValueArray[5]=48000;
  requestedBlockCount = 16;

  //consoleTextString = @"";
  //consoleStringQueue = [[NSMutableArray alloc]init];
  //causes a timer to constantly see if new strings are waiting to be written to the console
  //TODO start on didappear, pause on view disappear
  [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(consolePrintFunction) userInfo:nil repeats:YES];


  MMPFiles = [SettingsViewController getDocumentsOnlyMMP:YES];
  allFiles = [SettingsViewController getDocumentsOnlyMMP:NO];

  hardwareCanvasType = [SettingsViewController getCanvasType];

  int cornerRadius;
  int buttonRadius;
  if(hardwareCanvasType==canvasTypeWideTablet){
    cornerRadius=20;
    buttonRadius=10;
  }
  else{
    cornerRadius=10;
    buttonRadius=5;
  }

  //
  _mmpOrAll = [[NSUserDefaults standardUserDefaults] boolForKey:@"MMPShowAllFiles"];
  _flipped = [[NSUserDefaults standardUserDefaults] boolForKey:@"MMPFlipInterface"];
  _autoLoad = [[NSUserDefaults standardUserDefaults] boolForKey:@"MMPAutoLoadLastPatch"];

  //top buttons
  [_documentViewButton addTarget:self action:@selector(showLoadDoc:) forControlEvents:UIControlEventTouchUpInside];
  _documentViewButton.layer.cornerRadius = buttonRadius;
  _documentViewButton.layer.borderWidth = 1;
  _documentViewButton.layer.borderColor = [UIColor whiteColor].CGColor;

  [_consoleViewButton addTarget:self action:@selector(showConsole:) forControlEvents:UIControlEventTouchUpInside];
  _consoleViewButton.layer.cornerRadius = buttonRadius;
  _consoleViewButton.layer.borderWidth = 1;
  _consoleViewButton.layer.borderColor = [UIColor whiteColor].CGColor;

  [_audioMidiViewButton addTarget:self action:@selector(showDSP:) forControlEvents:UIControlEventTouchUpInside];
  _audioMidiViewButton.layer.cornerRadius = buttonRadius;
  _audioMidiViewButton.layer.borderWidth = 1;
  _audioMidiViewButton.layer.borderColor = [UIColor whiteColor].CGColor;

  [_networkViewButton addTarget:self action:@selector(showNetwork:) forControlEvents:UIControlEventTouchUpInside];
  _networkViewButton.layer.cornerRadius = buttonRadius;
  _networkViewButton.layer.borderWidth = 1;
  _networkViewButton.layer.borderColor = [UIColor whiteColor].CGColor;

  //documents
  _documentsTableView.delegate = self;
  _documentsTableView.dataSource = self;
  [_showFilesButton addTarget:self action:@selector(showFilesButtonHit:) forControlEvents:UIControlEventTouchUpInside];
  _showFilesButton.layer.cornerRadius = buttonRadius;
  _showFilesButton.layer.borderWidth = 1;
  _showFilesButton.layer.borderColor = [UIColor whiteColor].CGColor;
  _showFilesButton.titleLabel.adjustsFontSizeToFitWidth = YES;
  [self refreshShowFilesButton];

  [_flipInterfaceButton addTarget:self action:@selector(flipInterfaceButtonHit:) forControlEvents:UIControlEventTouchUpInside];
  _flipInterfaceButton.layer.cornerRadius = buttonRadius;
  _flipInterfaceButton.layer.borderWidth = 1;
  _flipInterfaceButton.layer.borderColor = [UIColor whiteColor].CGColor;
  [self refreshFlipButton];

  [_autoLoadButton addTarget:self action:@selector(autoLoadButtonHit:) forControlEvents:UIControlEventTouchUpInside];
  _autoLoadButton.layer.cornerRadius = buttonRadius;
  _autoLoadButton.layer.borderWidth = 1;
  _autoLoadButton.layer.borderColor = [UIColor whiteColor].CGColor;
  [self refreshAutoLoadButton];

  //console
  [_clearConsoleButton addTarget:self action:@selector(clearConsole:) forControlEvents:UIControlEventTouchUpInside];
  _clearConsoleButton.layer.cornerRadius = buttonRadius;
  _clearConsoleButton.layer.borderWidth = 1;
  _clearConsoleButton.layer.borderColor = [UIColor whiteColor].CGColor;

  //audio midi
  _midiSourceTableView.delegate = self;
  _midiSourceTableView.dataSource = self;
  _midiDestinationTableView.delegate = self;
  _midiDestinationTableView.dataSource = self;

  int actualTicks = [self.audioDelegate actualTicksPerBuffer];
  _tickSeg.selectedSegmentIndex = (int)log2(actualTicks);
  [_tickSeg addTarget:self action:@selector(tickSegChanged:) forControlEvents:UIControlEventValueChanged];
  [_rateSeg addTarget:self action:@selector(rateSegChanged:) forControlEvents:UIControlEventValueChanged];

  [_audioEnableButton addTarget:self action:@selector(audioEnableButtonHit ) forControlEvents:UIControlEventTouchDown];
  _audioEnableButton.layer.cornerRadius = 5;
  _audioEnableButton.layer.borderWidth = 1;
  _audioEnableButton.layer.borderColor = [UIColor whiteColor].CGColor;
  [_audioInputSwitch addTarget:self action:@selector(audioInputSwitchHit) forControlEvents:UIControlEventValueChanged];

  /*
  audioRouteView =  [[MPVolumeView alloc] initWithFrame:_audioRouteContainerView.frame];
  audioRouteView.showsRouteButton = YES;
  audioRouteView.showsVolumeSlider = NO;
  [_audioMidiContentView addSubview:audioRouteView];
  [audioRouteView sizeToFit];*/ //not working: on 8.4 pad, not showing at all (but didn't enable output routing), on phone, showing, but switching to it is garbled


  //Network

  [_networkTypeSeg addTarget:self action:@selector(networkSegChanged:) forControlEvents:UIControlEventValueChanged];

//  [_networkingSubView addSubview:_LANdiniSubView];
//  [_networkingSubView addSubview:_pingAndConnectSubView];
//  [_networkingSubView addSubview:_multiDirectConnectionSubView];

  //direct
  _ipAddressTextField.delegate = self;
  _ipAddressTextField.text = [MMPNetworkingUtils ipAddress];//self.delegate.outputIpAddress;

  [_ipAddressResetButton addTarget:self action:@selector(ipAddressResetButtonPressed) forControlEvents:UIControlEventTouchUpInside];

  _outputPortNumberTextField.delegate = self;
  _outputPortNumberTextField.text = [NSString stringWithFormat:@"%d", self.delegate.outputPortNumber];

  _inputPortNumberTextField.delegate = self;
  _inputPortNumberTextField.text = [NSString stringWithFormat:@"%d", self.delegate.inputPortNumber];

  //LANdini
  [_LANdiniEnableSwitch addTarget:self action:@selector(LANdiniSwitchHit:) forControlEvents:UIControlEventValueChanged];
  _LANdiniUserTableView.delegate = self;
  _LANdiniUserTableView.dataSource = self;

  // Ping and connect
  [_pingAndConnectEnableSwitch addTarget:self action:@selector(pingAndConnectSwitchHit:) forControlEvents:UIControlEventValueChanged];
  _pingAndConnectUserTableView.delegate = self;
  _pingAndConnectUserTableView.dataSource = self;
  [_pingAndConnectPlayerNumberSeg addTarget:self action:@selector(pingAndConnectPlayerNumberSegChanged:) forControlEvents:UIControlEventValueChanged];

  //
  _documentView.layer.cornerRadius = cornerRadius;
  _consoleView.layer.cornerRadius = cornerRadius;
  _audioMidiScrollView.layer.cornerRadius = cornerRadius;
  _networkView.layer.cornerRadius = cornerRadius;

  _documentsTableView.layer.cornerRadius = cornerRadius;
  _consoleTextView.layer.cornerRadius = cornerRadius;

  _midiSourceTableView.layer.cornerRadius = cornerRadius;
  _midiDestinationTableView.layer.cornerRadius = cornerRadius;
  _LANdiniUserTableView.layer.cornerRadius = cornerRadius;
  _pingAndConnectUserTableView.layer.cornerRadius = cornerRadius;

  if(hardwareCanvasType==canvasTypeWidePhone){
    if(SYSTEM_VERSION_LESS_THAN(@"7.0")){
      //segmented
      UIFont *font = [UIFont boldSystemFontOfSize:12.0f];
      NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:UITextAttributeFont];
      [_tickSeg setTitleTextAttributes:attributes forState:UIControlStateNormal];
      [_rateSeg setTitleTextAttributes:attributes forState:UIControlStateNormal];

      CGRect frame= _tickSeg.frame;
      [_tickSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 30)];
      frame= _rateSeg.frame;
      [_rateSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 30)];
    }
  }
  else if(hardwareCanvasType==canvasTypeTallPhone){
    if(SYSTEM_VERSION_LESS_THAN(@"7.0")){
      //segmented
      UIFont *font = [UIFont boldSystemFontOfSize:12.0f];
      NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:UITextAttributeFont];
      [_tickSeg setTitleTextAttributes:attributes forState:UIControlStateNormal];
      [_rateSeg setTitleTextAttributes:attributes forState:UIControlStateNormal];

      CGRect frame= _tickSeg.frame;
      [_tickSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 30)];
      frame= _rateSeg.frame;
      [_rateSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 30)];
    }
  }
  else{//ipad

    UIFont *font = [UIFont boldSystemFontOfSize:24.0f];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:UITextAttributeFont];
    [_tickSeg setTitleTextAttributes:attributes forState:UIControlStateNormal];
    [_rateSeg setTitleTextAttributes:attributes forState:UIControlStateNormal];

    if(SYSTEM_VERSION_LESS_THAN(@"7.0")){
      //segmented
      CGRect frame= _tickSeg.frame;
      [_tickSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 60)];
      frame= _rateSeg.frame;
      [_rateSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 60)];
    }
    else{//ios 7
      CGRect frame= _tickSeg.frame;
      [_tickSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height*2)];
      frame= _rateSeg.frame;
      [_rateSeg setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height*2)];
    }
  }
//Link
    ABLLinkRef linkRef = [APP getLinkRef];
    linkSettings_ = [ABLLinkSettingsViewController instance:linkRef];
  [self showLoadDoc:nil];
  [self updateAudioRouteLabel];
  [self updateAudioState];

}

- (void)updateAudioState {
  int rate = _audioDelegate.sampleRate;
  int tickPerBuffer = _audioDelegate.actualTicksPerBuffer;

  // set segmented with val

    if( fmod(log2(tickPerBuffer), 1)==0){
      int newBlockIndex = (int)log2(tickPerBuffer);
      [_tickSeg setSelectedSegmentIndex:newBlockIndex];
    } else {
      [_tickSeg setSelectedSegmentIndex:UISegmentedControlNoSegment];
    }


    [_rateSeg setSelectedSegmentIndex:UISegmentedControlNoSegment];
    for(int i=0;i<6;i++){
      if(rateValueArray[i]==rate) [_rateSeg setSelectedSegmentIndex:i];
    }

  int blockSize = [self.audioDelegate blockSize];
  [_tickValueLabel setText:[NSString stringWithFormat:@"buffer size = %d ticks * block size (%d) = %d samples", tickPerBuffer, blockSize, tickPerBuffer*blockSize]];
}

- (void)ipAddressResetButtonPressed {
  NSString *multicastAddress = @"224.0.0.1";
  _ipAddressTextField.text = multicastAddress;
  [self.delegate setOutputIpAddress:multicastAddress];
}

- (void)portDoneClicked:(id)sender {
  //NSLog(@"Done Clicked.");
  [self.view endEditing:YES];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  textField.text = @"";
}

- (BOOL)ipIsValid:(NSString *)inString {
  const char *utf8 = [inString UTF8String];
  int success;

  struct in_addr dst;
  success = inet_pton(AF_INET, utf8, &dst);
  if (success != 1) {
    struct in6_addr dst6;
    success = inet_pton(AF_INET6, utf8, &dst6);
  }
  return (success == 1);
}

- (BOOL)portNumberIsValid:(int)inInt {
  if (inInt >= 1000 && inInt <=65535) {
    return YES;
  }
  return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  //NSLog(@"text:%@", [textField text]);
  if(textField == _ipAddressTextField ) {
    if ([self ipIsValid:textField.text]) {
      [self.delegate setOutputIpAddress:[textField text]];
    } else {
      //alert?
      [self ipAddressResetButtonPressed];
    }
  } else if (textField == _outputPortNumberTextField) {
    if ([self portNumberIsValid:[textField.text intValue]]) {
      [self.delegate setOutputPortNumber:[textField.text intValue]];
    } else {
      [self showInvalidPortNumberAlert];
      // reset from delegate value
      _outputPortNumberTextField.text = [NSString stringWithFormat:@"%d", self.delegate.outputPortNumber];
    }
  } else if (textField == _inputPortNumberTextField) {
    if ([self portNumberIsValid:[textField.text intValue]]) {
      [self.delegate setInputPortNumber:[textField.text intValue]];
    } else {
      [self showInvalidPortNumberAlert];
      // reset from delegate value
      _inputPortNumberTextField.text = [NSString stringWithFormat:@"%d", self.delegate.inputPortNumber];
    }
  }
}

- (void)showInvalidPortNumberAlert {
  UIAlertView *alert = [[UIAlertView alloc]
                            initWithTitle: @"Bad format"
                            message: @"This is not a valid port number"
                            delegate: nil
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
      [alert show];
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
  [theTextField resignFirstResponder];
  return YES;
}

-(void)viewDidAppear:(BOOL)animated{
    [_documentsTableView reloadData];
  [super viewDidAppear:animated];
  _outputPortNumberTextField.text = [NSString stringWithFormat:@"%d",self.delegate.outputPortNumber];
  _inputPortNumberTextField.text = [NSString stringWithFormat:@"%d",self.delegate.inputPortNumber];
  _ipAddressTextField.text = self.delegate.outputIpAddress;

  // start timer to check SSID name. This is because switching networks does not trigger a reachability change.
  [self checkReach];
  _updateNetworkLabelTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                              target:self
                                                            selector:@selector(checkReach)
                                                            userInfo:nil
                                                             repeats:YES];

  // update network switches. TODO: needs an observer in case enabled changes state while looking at settings
  _LANdiniEnableSwitch.on = self.LANdiniDelegate.LANdiniEnabled;
  _pingAndConnectEnableSwitch.on = self.pingAndConnectDelegate.pingAndConnectEnabled;
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  [_updateNetworkLabelTimer invalidate];
  _updateNetworkLabelTimer = nil;
}

-(void)checkReach{
  Reachability *reach = [self.LANdiniDelegate getReachability]; //TODO move reachability object
  [self updateNetworkLabel:reach];
}

-(void)updateAudioRouteLabel{
  if([[AVAudioSession sharedInstance] respondsToSelector:@selector(currentRoute)]){//ios 5 doesn't find selector

    AVAudioSessionRouteDescription* asrd = [[AVAudioSession sharedInstance] currentRoute];
    NSString* inputString = @"input:(none)";
    if([[asrd inputs] count] > 0 ){
      AVAudioSessionPortDescription* aspd = [[asrd inputs] objectAtIndex:0];
      inputString = [NSString stringWithFormat:@"input:%@ channels:%ld", aspd.portName, (long)[[AVAudioSession sharedInstance] inputNumberOfChannels] ];
    }
    NSString* outputString = @"output:(none)";
    if([[asrd outputs] count] > 0 ){
      AVAudioSessionPortDescription* aspd = [[asrd outputs] objectAtIndex:0];
      outputString = [NSString stringWithFormat:@"output:%@ channels:%ld", aspd.portName, (long)[[AVAudioSession sharedInstance] outputNumberOfChannels] ];
    }
    _audioRouteLabel.text = [NSString stringWithFormat:@"%@\n%@", inputString, outputString];
    //[self consolePrint:[NSString stringWithFormat:@"%@\n%@", inputString, outputString] ];
  }

}

-(void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  _audioMidiScrollView.contentSize = _audioMidiContentView.frame.size;

  //small screen, rate numbers get cut off unless made smaller
  if (self.view.frame.size.width == 320) {
    UIFont *font = [UIFont boldSystemFontOfSize:10.0f];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font
                                                           forKey:NSFontAttributeName];
    [_rateSeg setTitleTextAttributes:attributes
                                    forState:UIControlStateNormal];
  }
}

-(void)viewWillAppear:(BOOL)animated{
  _consoleTextView.text = consoleTextString;
  //ios 7 bug
  if(hardwareCanvasType==canvasTypeWidePhone || hardwareCanvasType==canvasTypeTallPhone)
    [_consoleTextView setFont:[UIFont systemFontOfSize:16]];
  else [_consoleTextView setFont:[UIFont systemFontOfSize:24]];

  [_consoleTextView scrollRangeToVisible:(NSRange){consoleTextString.length-1, 1}];


}

-(void)refreshAudioEnableButton{
  if(self.audioDelegate.backgroundAudioAndNetworkEnabled){
    [_audioEnableButton setTitle:@"enabled" forState:UIControlStateNormal];
    [_audioEnableButton setBackgroundColor:[UIColor whiteColor]];
    [_audioEnableButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
  }

  else{
    [_audioEnableButton setTitle:@"disabled" forState:UIControlStateNormal];
    [_audioEnableButton setBackgroundColor:[UIColor clearColor]];
    [_audioEnableButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  }
}

-(void)audioEnableButtonHit{
  self.audioDelegate.backgroundAudioAndNetworkEnabled=!self.audioDelegate.backgroundAudioAndNetworkEnabled;
  [self refreshAudioEnableButton];
}

BOOL audioSwitchBool;
-(void)audioInputSwitchHit{

  if(audioSwitchBool!=_audioInputSwitch.on){
    audioSwitchBool=_audioInputSwitch.on;

    if(_audioInputSwitch.on){
      [self.audioDelegate setAudioInputEnabled:NO];//overide to turn mic off, vib on;
    }
    else [self.audioDelegate setAudioInputEnabled:YES];
  }
}

BOOL LANdiniSwitchBool;
-(void)LANdiniSwitchHit:(UISwitch*)sender{
  if(LANdiniSwitchBool!=_LANdiniEnableSwitch.on){
    LANdiniSwitchBool=_LANdiniEnableSwitch.on;
    //if([self.LANdiniDelegate respondsToSelector:@selector(enableLANdini:)]){
      self.LANdiniDelegate.LANdiniEnabled = [sender isOn];
    //}

    if([sender isOn]){
      _networkTimer = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(networkTime:) userInfo:nil repeats:YES];
    }
    else{
      [_networkTimer invalidate];
      _networkTimer = nil;
      _LANdiniTimeLabel.text = @"Network time:";
    }
  }
}

- (void)pingAndConnectSwitchHit:(UISwitch*)sender {
  self.pingAndConnectDelegate.pingAndConnectEnabled = [sender isOn];
}

- (void)pingAndConnectPlayerNumberSegChanged:(UISegmentedControl *)sender {
  NSInteger index = [sender selectedSegmentIndex];
  if (index == 1)index = -1; //SERVER val, move it
  else if (index > 1) index -= 1;
  [_pingAndConnectDelegate setPingAndConnectPlayerNumber:index];
}

-(void)networkTime:(NSTimer*)timer{
  _LANdiniTimeLabel.text = [NSString stringWithFormat:@"Network time via %@:%.2f", _LANdiniSyncServerName, [self.LANdiniDelegate getLANdiniTime] ];
}


- (void)done:(id)sender {
  [self.delegate settingsViewControllerDidFinish:self];
}


-(void)showFilesButtonHit:(id)sender{
  _mmpOrAll = !_mmpOrAll;
  [self reloadFileTable];
  [[NSUserDefaults standardUserDefaults] setBool:_mmpOrAll forKey:@"MMPShowAllFiles"]; //Move to view did close.
  [self refreshShowFilesButton];
}

-(void)refreshShowFilesButton {
  if(_mmpOrAll){//is showing mmp, change to show all
    _showFilesButton.backgroundColor = [UIColor whiteColor];
    [_showFilesButton setTitleColor:[UIColor purpleColor] forState:UIControlStateNormal];
  } else {
    _showFilesButton.backgroundColor = [UIColor purpleColor];
    [_showFilesButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  }
}

-(void)flipInterfaceButtonHit:(id)sender{
  _flipped = !_flipped;
  [self.delegate flipInterface:_flipped];
  [[NSUserDefaults standardUserDefaults] setBool:_flipped forKey:@"MMPFlipInterface"];
  [self refreshFlipButton];
}

- (void)refreshFlipButton {
  if (_flipped) {
    _flipInterfaceButton.backgroundColor = [UIColor whiteColor];
    [_flipInterfaceButton setTitleColor:[UIColor purpleColor] forState:UIControlStateNormal];
  } else{
    _flipInterfaceButton.backgroundColor = [UIColor purpleColor];
    [_flipInterfaceButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  }
}

-(void)autoLoadButtonHit:(id)sender {
  _autoLoad = !_autoLoad;
  [[NSUserDefaults standardUserDefaults] setBool:_autoLoad forKey:@"MMPAutoLoadLastPatch"];
  [self refreshAutoLoadButton];
}

- (void)refreshAutoLoadButton {
  if(_autoLoad){
    _autoLoadButton.backgroundColor = [UIColor whiteColor];
    [_autoLoadButton setTitleColor:[UIColor purpleColor] forState:UIControlStateNormal];
  } else{
    _autoLoadButton.backgroundColor = [UIColor purpleColor];
    [_autoLoadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  }
}

-(void) showLoadDoc:(id)sender{
  _documentViewButton.enabled=NO;
  _audioMidiViewButton.enabled=YES;
  _consoleViewButton.enabled=YES;
  _networkViewButton.enabled = YES;
  [self.view bringSubviewToFront:_documentView];
  self.navigationItem.title = @"Select Document";

}
-(void)showConsole:(id)sender{
  _documentViewButton.enabled=YES;
  _audioMidiViewButton.enabled=YES;
  _consoleViewButton.enabled=NO;
  _networkViewButton.enabled = YES;
  [self.view bringSubviewToFront:_consoleView];
  self.navigationItem.title = @"Pd Console";

}

- (void)showDSP:(id)sender {
  _documentViewButton.enabled=YES;
  _audioMidiViewButton.enabled=NO;
  _consoleViewButton.enabled=YES;
  _networkViewButton.enabled = YES;
  [self.view bringSubviewToFront:_audioMidiScrollView];
  self.navigationItem.title = @"Audio MIDI Settings";

}

- (void)showNetwork:(id)sender {
  _documentViewButton.enabled=YES;
  _audioMidiViewButton.enabled=YES;
  _consoleViewButton.enabled=YES;
  _networkViewButton.enabled = NO;
  [self.view bringSubviewToFront:_networkView];
  self.navigationItem.title = @"Network";

}

-(void)clearConsole:(id)sender{
  consoleTextString=@"";
  _consoleTextView.text = consoleTextString;
}

//adds string to queue
-(void)consolePrint:(NSString *)message{
  [consoleStringQueue addObject:message];
}

//called often by timer
-(void)consolePrintFunction{

  if([consoleStringQueue count]==0)return;//nothing to print

  //take all the string in the queue and shove them into one big string
  NSString* newString = [consoleStringQueue componentsJoinedByString:@"\n"];
  consoleTextString = [consoleTextString stringByAppendingFormat:@"\n%@", newString];//append to currently shown string
  int startPoint = [consoleTextString length]-2000; if (startPoint<0)startPoint=0;
  NSRange stringRange = {startPoint, MIN([consoleTextString length], 2000)};//chop off front of string to fit
  consoleTextString = [consoleTextString substringWithRange:stringRange];
  [consoleStringQueue removeAllObjects];

  if (self.isViewLoaded && self.view.window) {//if I am on screen, show and scroll
    _consoleTextView.text = consoleTextString;
    [_consoleTextView scrollRangeToVisible:(NSRange){consoleTextString.length-1, 1}];

    //ios 7 bug, font needs to be set after setting text
    if(hardwareCanvasType==canvasTypeWidePhone || hardwareCanvasType==canvasTypeTallPhone)
      [_consoleTextView setFont:[UIFont systemFontOfSize:16]];
    else [_consoleTextView setFont:[UIFont systemFontOfSize:24]];

  }

}

- (void)networkSegChanged:(UISegmentedControl*)sender{
  NSUInteger index = [sender selectedSegmentIndex];
  switch (index) {
    case 0: [_networkingSubView bringSubviewToFront: _multiDirectConnectionSubView]; break;
    case 1: [_networkingSubView bringSubviewToFront: _pingAndConnectSubView]; break;
    case 2: [_networkingSubView bringSubviewToFront: _LANdiniSubView]; break;
  }
}

-(void)tickSegChanged:(UISegmentedControl*)sender{
  NSUInteger index = [sender selectedSegmentIndex];
  requestedBlockCount = (int)pow(2, index);
  [self.audioDelegate setTicksPerBuffer:requestedBlockCount]; //triggers updateAudioState
}

-(void)rateSegChanged:(UISegmentedControl*)sender {
  NSUInteger index = [sender selectedSegmentIndex];
  int newRate = rateValueArray[index];
  [self.audioDelegate setRate:newRate]; //triggers updateAudioState
}


-(void)reloadFileTable{
  MMPFiles = [SettingsViewController getDocumentsOnlyMMP:YES];
  allFiles = [SettingsViewController getDocumentsOnlyMMP:NO];
  [_documentsTableView reloadData];
}

-(void)reloadMidiSources{
  [_midiSourceTableView reloadData];
  [_midiDestinationTableView reloadData];
}

//landini


//load a pure data file from an index path on the filesTable
-(void)selectHelper:(NSIndexPath*)indexPath{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *publicDocumentsDir = [paths objectAtIndex:0];

  //pull filename from either allFiles or MMPFiles, depending on which list we are looking at
  NSString* filename = [(_mmpOrAll ? allFiles : MMPFiles)objectAtIndex:[indexPath row]];
  NSString* fullPath = [publicDocumentsDir stringByAppendingPathComponent:filename];
  NSString* suffix = [[filename componentsSeparatedByString: @"."] lastObject];

  //if an MMP file, open JSONString and load it
  if([suffix isEqualToString:@"mmp"]){
    //BOOL loaded = [self.delegate loadScene:sceneDict];
    BOOL loaded = [self.delegate loadMMPSceneFromDocPath:filename];
    if(loaded)[self.delegate settingsViewControllerDidFinish:self];//successful load, flip back to main ViewController
    else{//failed load
      UIAlertView *alert = [[UIAlertView alloc]
                            initWithTitle: @"Bad format"
                            message: @"This .mmp file is not formatted correctly"
                            delegate: nil
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
      [alert show];
    }
  }

  //zip file, attempt to unarchive and copy contents into documents folder
  else if ([suffix isEqualToString:@"zip"]){
    ZipArchive* za = [[ZipArchive alloc] init];

    if( [za UnzipOpenFile:fullPath] ) {
      if( [za UnzipFileTo:publicDocumentsDir overWrite:YES] != NO ) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle: @"Archive Decompressed"
                              message: [NSString stringWithFormat:@"Decompressed contents of %@ to MobMuPlat Documents", filename]
                              delegate: nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
        NSError* error;
        [[NSFileManager defaultManager]removeItemAtPath:fullPath error:&error];
        [self reloadFileTable];
      }
      else{
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle: @"Archive Failure"
                              message: [NSString stringWithFormat:@"Could not decompress contents of %@", filename]
                              delegate: nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
      }

      [za UnzipCloseFile];
    }
  }

  //pd file, load the file via "loadScenePatchOnly"
  else if ([suffix isEqualToString:@"pd"]){
    if (SYSTEM_VERSION_LESS_THAN(@"6.0")) {
      UIAlertView *alert = [[UIAlertView alloc]
                            initWithTitle: @"Too old..."
                            message: @"Opening native PD GUIs requires iOS 6 and above."
                            delegate: nil
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
      [alert show];
      return;
    }

    BOOL loaded = [self.delegate loadScenePatchOnlyFromDocPath:filename];
    if(loaded)[self.delegate settingsViewControllerDidFinish:self];
    else{
      UIAlertView *alert = [[UIAlertView alloc]
       initWithTitle: @"Bad PD format"
       message: @"Could not open PD file"
       delegate: nil
       cancelButtonTitle:@"OK"
       otherButtonTitles:nil];
       [alert show];
    }
  }
}

-(void)deleteHelper:(NSIndexPath*)indexPath {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *publicDocumentsDir = [paths objectAtIndex:0];

  //pull filename from either allFiles or MMPFiles, depending on which list we are looking at
  NSString* filename = [(_mmpOrAll ? allFiles : MMPFiles)objectAtIndex:[indexPath row]];
  NSString* fullPath = [publicDocumentsDir stringByAppendingPathComponent:filename];
  //NSString* suffix = [[filename componentsSeparatedByString: @"."] lastObject];

  if([fileManager fileExistsAtPath:fullPath]){
    BOOL success = [fileManager removeItemAtPath:fullPath error:nil];
    if (!success) {
      UIAlertView *alert = [[UIAlertView alloc]
                            initWithTitle: @"Hmm"
                            message: @"Could not delete file from Documents."
                            delegate: nil
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
      [alert show];

    } else{//success
      [(_mmpOrAll ? allFiles : MMPFiles) removeObjectAtIndex:[indexPath row]];
    }
  }
  //else error?

}

//tableView delegate methods

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  if(tableView==_documentsTableView) return UITableViewCellEditingStyleDelete;
  else return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete && tableView==_documentsTableView) {
    [tableView beginUpdates];

    [self deleteHelper:indexPath];

    [tableView deleteRowsAtIndexPaths:@[indexPath]
                     withRowAnimation:UITableViewRowAnimationFade];
    [tableView endUpdates];
  }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView==_midiSourceTableView) {
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;

    NSUInteger index = indexPath.row;
    NSArray *sources = [[self.audioDelegate midi] sources];
    if (index >= [sources count]) {
      return; //error
    }
    [self.audioDelegate disconnectMidiSource:sources[index]];
  } else if (tableView==_midiDestinationTableView) {
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;

    NSUInteger index = indexPath.row;
    NSArray *destinations = [[self.audioDelegate midi] destinations];
    if (index >= [destinations count]) {
      return; //error
    }
    [self.audioDelegate disconnectMidiDestination:destinations[index]];
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if(tableView==_documentsTableView){
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];

    //add an activity indicator
    UIActivityIndicatorView* aiv = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    aiv.frame = CGRectMake(0, 0, 24, 24);
    [cell setAccessoryView:aiv];
    [aiv startAnimating];

    //load the pd file
    [self performSelector:@selector(selectHelper:) withObject:indexPath afterDelay:0];

    //done
    [aiv performSelector:@selector(stopAnimating) withObject:nil afterDelay:0];//performSelector: puts method call on next run loop
  } else if (tableView==_midiSourceTableView){

    NSUInteger index = indexPath.row;
    NSArray *sources = [[self.audioDelegate midi] sources];
    if (index >= [sources count]) {
      return; //error
    }

    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    [self.audioDelegate connectMidiSource:sources[index]];
  }
  else if (tableView==_midiDestinationTableView){
    NSUInteger index = indexPath.row;
    NSArray *destinations = [[self.audioDelegate midi] destinations];
    if (index >= [destinations count]) {
      return; //error
    }
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    [self.audioDelegate connectMidiDestination:destinations[index]];
    
  }
  /*else if (tableView==_LANdiniUserTableView){
   [self.LANdiniDelegate ]
   }*/
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if(tableView == _documentsTableView)return [(_mmpOrAll ? allFiles : MMPFiles) count];
  else if (tableView==_midiSourceTableView)return [[[self.audioDelegate midi] sources]  count];
  else if (tableView==_midiDestinationTableView)return [[[self.audioDelegate midi] destinations]  count];
  else if (tableView==_LANdiniUserTableView) return [_LANdiniUserArray count];
  else if (tableView==_pingAndConnectUserTableView) return [_pingAndConnectUserArray count];
  else return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
  return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
  if(tableView == _documentsTableView){
    if (hardwareCanvasType==canvasTypeWideTablet)return 70;
    else return 35;
  }
  else {//midi and landini tables
    if (hardwareCanvasType==canvasTypeWideTablet)return 45;
    else return 22.5;
  }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
  if(tableView == _documentsTableView) {
    //if we are looking at MMP files only, then everything is highlightable.
//    if(!_mmpOrAll)return YES;

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    //todo centralize this repeated logic
    NSString* suffix = [[cell.textLabel.text componentsSeparatedByString: @"."] lastObject];
      BOOL whatToReturn = YES;
    if([suffix isEqualToString:@"mmp"] || [suffix isEqualToString:@"zip"] || [suffix isEqualToString:@"pd"]){
        //exclude loaded scenes
        for (NSArray *ar in [(MMPViewController *)[APP viewController] sceneArray]) {
            if ([cell.textLabel.text hasPrefix:ar[0]]) {
                whatToReturn = NO;
                break;
            }
        }
        return whatToReturn;
    }
    else return NO;
  } else { // other tables
    return YES;
  }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if(tableView == _documentsTableView){
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:documentsTableCellIdentifier];

    if (cell == nil) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:documentsTableCellIdentifier];
      if (hardwareCanvasType==canvasTypeWideTablet)cell.textLabel.font=[UIFont systemFontOfSize:32];
      else cell.textLabel.font=[UIFont systemFontOfSize:16];
    }

    cell.textLabel.text=[(_mmpOrAll ? allFiles : MMPFiles) objectAtIndex:[indexPath row]];
    NSString* suffix = [[[(_mmpOrAll ? allFiles : MMPFiles) objectAtIndex:[indexPath row]] componentsSeparatedByString: @"."] lastObject];
    if([suffix isEqualToString:@"mmp"] || [suffix isEqualToString:@"zip"] || [suffix isEqualToString:@"pd"]){
        
        for (NSArray *ar in [(MMPViewController *)[APP viewController] sceneArray]) {
            if ([cell.textLabel.text hasPrefix:ar[0]]) {
                cell.textLabel.textColor = [UIColor grayColor];
//                cell.userInteractionEnabled = NO;
                break;
            }
            else {
                cell.textLabel.textColor = [UIColor blackColor];
//                cell.userInteractionEnabled = YES;
            }
        }
    }
    else {
        cell.textLabel.textColor = [UIColor lightGrayColor];
//      cell.userInteractionEnabled=NO;
    }
    if (@available(iOS 13.0, *)) {
        cell.backgroundColor = [UIColor systemGray4Color];
    }

    return cell;
  }

  else if (tableView==_midiSourceTableView){
    PGMidiConnection* currSource = [[[self.audioDelegate midi] sources] objectAtIndex: [indexPath indexAtPosition:1]];
    NSString* currMidiSourceName = currSource.name;
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:midiTableCellIdentifier];

    if(cell==nil){
      cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:midiTableCellIdentifier] ;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      if (hardwareCanvasType==canvasTypeWideTablet)cell.textLabel.font=[UIFont systemFontOfSize:24];
      else cell.textLabel.font=[UIFont systemFontOfSize:12];
    }
    [cell textLabel].text=currMidiSourceName;
    cell.accessoryType = [self.audioDelegate isConnectedToConnection:currSource] ?
       UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
  }

  else if (tableView==_midiDestinationTableView){
    PGMidiConnection* currDestination = [[[self.audioDelegate midi] destinations] objectAtIndex: [indexPath indexAtPosition:1]];
    NSString* currMidiDestName = currDestination.name;
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:midiTableCellIdentifier];

    if(cell==nil){
      cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:midiTableCellIdentifier] ;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      if (hardwareCanvasType==canvasTypeWideTablet)cell.textLabel.font=[UIFont systemFontOfSize:24];
      else cell.textLabel.font=[UIFont systemFontOfSize:12];
    }
    [cell textLabel].text=currMidiDestName;
    cell.accessoryType = [self.audioDelegate isConnectedToConnection:currDestination] ?
       UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;

  }

  else if (tableView==_LANdiniUserTableView){
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:landiniTableCellIdentifier];
    LANdiniUser* user = [_LANdiniUserArray objectAtIndex:[indexPath row]];

    if(cell==nil){
      cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:landiniTableCellIdentifier] ;
      if (hardwareCanvasType==canvasTypeWideTablet)cell.textLabel.font=[UIFont systemFontOfSize:18];
      else cell.textLabel.font=[UIFont systemFontOfSize:12];
    }
    [cell textLabel].text=[NSString stringWithFormat:@"%@ - %@", user.name, user.ip];
    return cell;
  } else if (tableView==_pingAndConnectUserTableView) {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:pingAndConnectTableCellIdentifier];
    NSString* userString = [_pingAndConnectUserArray objectAtIndex:[indexPath row]];

    if(cell==nil){
      cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:pingAndConnectTableCellIdentifier] ;
      if (hardwareCanvasType==canvasTypeWideTablet)cell.textLabel.font=[UIFont systemFontOfSize:18];
      else cell.textLabel.font=[UIFont systemFontOfSize:12];
    }
    [cell textLabel].text = userString;
    return cell;
  }
}

#pragma mark LANdiniUserDelegate - can be on non-main threads

-(void)landiniUserStateChanged:(NSArray*)userArray{
  _LANdiniUserArray = userArray;
  dispatch_async(dispatch_get_main_queue(), ^{
    [_LANdiniUserTableView reloadData];
  });
}

-(void)syncServerChanged:(NSString*)newServerName{
  _LANdiniSyncServerName = newServerName;
}

#pragma mark PingAndConnectUserDelegate - can be on non-main threads

- (void)pingAndConnectUserStateChanged:(NSArray*)userArray {
  _pingAndConnectUserArray = userArray;
  dispatch_async(dispatch_get_main_queue(), ^{
    [_pingAndConnectUserTableView reloadData];
  });
}

#pragma mark reachability from vC
-(void)reachabilityChanged:(NSNotification*)note {
  Reachability* reach = (Reachability*)note.userInfo;
  [self updateNetworkLabel:reach];

}

-(void)updateNetworkLabel:(Reachability*)reach{
  if ([reach isReachable]) {
    NSString* network = [MMPViewController fetchSSIDInfo];
    [_LANdiniNetworkLabel setText:[NSString stringWithFormat:@"Wifi network enabled: %@ \nMy IP address: %@", network ? network : @"", [MMPNetworkingUtils ipAddress]]];
  } else {
    _LANdiniNetworkLabel.text = @"Wifi network disabled";
  }
}

# pragma mark AudioBus

- (void)connectionsChanged:(NSNotification*)notification {
  /*TODO
   // Cancel any scheduled shutdown
   [NSObject cancelPreviousPerformRequestsWithTarget:_audioEngine selector:@selector(stop) object:nil];
   if ( !_audiobusController.connected && _audioEngine.running
   && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
   // Shut down after 10 seconds if we disconnected while in the background
   [_audioEngine performSelector:@selector(stop) withObject:nil afterDelay:10.0];
   }*/

  if([self.audioDelegate respondsToSelector:@selector(isAudioBusConnected)]){
    if([self.audioDelegate isAudioBusConnected]) {
      _rateSeg.enabled=NO;
      _tickSeg.enabled=NO;
      _audioEnableButton.enabled=NO;
      [_audioEnableButton setTitle:@"AudioBus" forState:UIControlStateNormal];
    }
    else{
      _rateSeg.enabled=YES;
      _tickSeg.enabled=YES;
      _audioEnableButton.enabled=YES;
      [self refreshAudioEnableButton];
    }
  }

}

# pragma mark cleanup

-(void)viewDidUnload{
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationDidBecomeActiveNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:kReachabilityChangedNotification
                                                object:nil];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

-(IBAction)showLinkSettings:(id)sender
{
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:linkSettings_];
    // this will present a view controller as a popover in iPad and a modal VC on iPhone
    linkSettings_.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(hideLinkSettings:)];
    
    navController.modalPresentationStyle = UIModalPresentationPopover;
    
    UIPopoverPresentationController *popC = navController.popoverPresentationController;
    popC.permittedArrowDirections = UIPopoverArrowDirectionAny;
    popC.sourceRect = [sender frame];
    
    // we recommend using a size of 320x400 for the display in a popover
    linkSettings_.preferredContentSize = CGSizeMake(320.f, 400.f);
    
    UIButton *button = (UIButton *)sender;
    popC.sourceView = button.superview;
    
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)hideLinkSettings:(id)sender
{
#pragma unused(sender)
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
