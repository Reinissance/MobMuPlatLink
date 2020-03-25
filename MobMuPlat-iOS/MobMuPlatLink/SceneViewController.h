//
//  SceneViewController.h
//  MobMuPlatLink
//
//  Created by Reinhard Sasse on 02.02.19.
//  Copyright © 2019 Daniel Iglesia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MeControl.h"
#import "MMPGui.h"

NS_ASSUME_NONNULL_BEGIN

@interface SceneViewController : UIViewController <PdReceiverDelegate, ControlDelegate, UIScrollViewDelegate>

@property NSDictionary *sceneDict;
@property UIButton *settingsButton;
@property UIScrollView *scrollView; // MMP gui
@property MMPGui *pdGui; // Keep strong reference here, for widgets to refer to weakly.
@property UIView *pdPatchView;
// key = address, value = array of objects with that address.
@property NSMutableDictionary<NSString *, NSMutableArray<MeControl *> *> *addressToGUIObjectsDict;

@property int sceneArrayIndex;
@property int pageCount;
@property NSString *filename;

- (void) dismiss;
- (instancetype) initWithSceneDict: (NSDictionary *)sceneDict;
- (instancetype) initWithPatchIndex:(int) index andPath: (NSString*) path;

- (BOOL)loadScenePatchOnlyFromPath:(NSString *)fromPath;
- (BOOL) loadJSON;

@property BOOL isLandscape;

@property void *pdPatch;

@end

NS_ASSUME_NONNULL_END
