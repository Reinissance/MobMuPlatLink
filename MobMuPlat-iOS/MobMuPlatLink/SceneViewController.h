//
//  SceneViewController.h
//  MobMuPlatLink
//
//  Created by Reinhard Sasse on 02.02.19.
//  Copyright © 2019 Daniel Iglesia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MeControl.h"

NS_ASSUME_NONNULL_BEGIN

@interface SceneViewController : UIViewController <ControlDelegate, UIScrollViewDelegate>

@property NSDictionary *sceneDict;
@property UIButton *settingsButton;
@property UIScrollView *scrollView; // MMP gui
@property int sceneArrayIndex;
@property int pageCount;

- (void) dismiss;
- (instancetype) initWithSceneDict: (NSDictionary *)sceneDict;
- (instancetype) initWithPatchIndex:(int) index;

@end

NS_ASSUME_NONNULL_END
