//
//  ViewController.h
//  MobMuPlat
//
//  Created by Daniel Iglesia on 11/15/12.
//  Copyright (c) 2012 Daniel Iglesia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import "PdAudioController.h"
#import "PdBase.h"
#import "PdFile.h"

#import "Reachability.h"

#import "SettingsViewController.h"
#import "MeControl.h"
#import "PGMidi.h"
#import "VVOSC.h"
#import "LANdiniLANManager.h"
#import "PingAndConnectManager.h"

#import "MMPPdDispatcher.h"

//@class OSCManager, OSCInPort, OSCOutPort;

#import "Audiobus.h"

#import "SceneViewController.h"

@interface MMPViewController : UIViewController<PdReceiverDelegate, UIAccelerometerDelegate,  SettingsViewControllerDelegate, ControlDelegate, UIScrollViewDelegate, AudioSettingsDelegate, PGMidiDelegate, PGMidiSourceDelegate, OSCDelegateProtocol, PdMidiReceiverDelegate, CLLocationManagerDelegate, LANdiniDelegate, PingAndConnectDelegate,MMPPdDispatcherPrintDelegate, UITableViewDelegate, UITableViewDataSource, UIDropInteractionDelegate>{
    
    
    
  //
  @public // exposed for testing
  LANdiniLANManager *_llm;
  PingAndConnectManager *_pacm;
}

// TODO separate audiobus.
- (instancetype)initWithAudioBusEnabled:(BOOL)audioBusEnabled NS_DESIGNATED_INITIALIZER;

-(void)connectPorts;
-(void)disconnectPorts;
+(NSString*)fetchSSIDInfo;
+(MMPDeviceCanvasType)getCanvasType;

@property BOOL backgroundAudioAndNetworkEnabled; //clean up
@property BOOL isPortsConnected; //clean up
@property (retain) PdAudioController* audioController;
@property (retain) SettingsViewController* settingsVC;

@property MMPPdDispatcher *mmpPdDispatcher;

//audio bus - make private
@property (strong, nonatomic) ABAudiobusController *audiobusController; //clean up
@property (assign,nonatomic)NSInteger ticks;

// called from app delegate
- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

//testing
- (BOOL)loadScenePatchOnlyFromBundle:(NSBundle *)bundle filename:(NSString *)filename;

@property UILabel *sceneLabel;
@property UITableView *sceneView;
@property NSMutableArray *sceneArray;

// key = address, value = array of objects with that address.
//@property NSMutableDictionary<NSString *, NSMutableArray<MeControl *> *> *addressToGUIObjectsDict;

@property BOOL uiIsFlipped; // Whether the UI has been inverted by the user.
//@property BOOL isLandscape;
@property SceneViewController *sceneController;
@property CGFloat settingsButtonDim; // Width/height of settings menu button.
@property CGFloat settingsButtonOffset; // Offset of menu button from edge of screen.

@property BOOL blockK2pd;

@end
