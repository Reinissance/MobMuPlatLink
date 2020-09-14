//
//  AppDelegate.h
//  MobMuPlat
//
//  Created by Daniel Iglesia on 11/15/12.
//  Copyright (c) 2012 Daniel Iglesia. All rights reserved.
//

#import <UIKit/UIKit.h>

#include "ABLLink.h"

@class MMPViewController;


@interface AppDelegate : UIResponder <UIApplicationDelegate>{
    
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) MMPViewController *viewController;

- (void) handleFileFromUrl: (NSURL*) url;

- (ABLLinkRef)getLinkRef;

@end
