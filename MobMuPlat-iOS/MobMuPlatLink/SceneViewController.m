//
//  SceneViewController.m
//  MobMuPlatLink
//
//  Created by Reinhard Sasse on 02.02.19.
//  Copyright © 2019 Daniel Iglesia. All rights reserved.
//

#import "SceneViewController.h"
#import "SettingsViewController.h"
#import "MMPViewController.h"
#import "PdBase.h"
#import "AppDelegate.h"

#import "MeSlider.h"
#import "MeKnob.h"
#import "MeLabel.h"
#import "MeButton.h"
#import "MeToggle.h"
#import "MeXYSlider.h"
#import "MeGrid.h"
#import "MePanel.h"
#import "MeMultiSlider.h"
#import "MeLCD.h"
#import "MeMultiTouch.h"
#import "MeUnknown.h"
#import "MeMenu.h"
#import "MeTable.h"

#import "PdParser.h"
#import "PdBase.h"
#import "MMPPdPatchDisplayUtils.h"

#define APP ((AppDelegate *)[[UIApplication sharedApplication] delegate])

@interface SceneViewController ()

@end

@implementation SceneViewController

- (instancetype) initWithSceneDict: (NSDictionary *)sceneDict {
    
    _sceneDict = sceneDict;
    _addressToGUIObjectsDict = [[NSMutableDictionary alloc]init];
//    _mmpPdDispatcher = [[MMPPdDispatcher alloc] init];
//    [Widget setDispatcher:APP.viewController.mmpPdDispatcher];
//    [PdBase setDelegate:_mmpPdDispatcher];
    [APP.viewController.mmpPdDispatcher addListener:self forSource:@"toGUI"];
    [self loadStyle];
    return self;
}

- (instancetype) initWithPatchIndex:(int) index andPath: (NSString*) path {
    _sceneArrayIndex = index;
    _pdGui = [[MMPGui alloc] init];
    [self loadStyle];
    return self;
}

- (void) loadStyle {
    self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setTitle:@"Back" forState:UIControlStateNormal];
    backButton.frame = CGRectMake(10.0, 10.0, 40.0, 20.0);
    backButton.titleLabel.textColor = [UIColor grayColor];
    [backButton addTarget:self action:@selector(backPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
}

- (void) backPressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// layout
UIView *_scrollInnerView;
UIView *_pdPatchView; //Native gui
PdFile *_openPDFile;
//MMPPdDispatcher *_mmpPdDispatcher;

//BOOL _uiIsFlipped; // Whether the UI has been inverted by the user.
//BOOL _isLandscape;


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    APP.viewController.sceneController = self;
    // Do any additional setup after loading the view.
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    APP.viewController.sceneController = nil;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - scrollview delegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _scrollInnerView;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)inScrollView {
    if (inScrollView == _scrollView) {
        int page = inScrollView.contentOffset.x / inScrollView.frame.size.width;
        [PdBase sendList:@[ @"/page", @(page) ] toReceiver:@"fromSystem"];
    }
}

- (void) dismiss {
    [self dismissViewControllerAnimated:YES completion:^{
        //TODO dealloc
        [_addressToGUIObjectsDict removeAllObjects];
//        [_mmpPdDispatcher removeAllListeners];
        [APP.viewController.mmpPdDispatcher removeListener:self forSource:@"toGUI"];
        for (Widget *widget in _pdGui.widgets) {
            [widget removeFromSuperview];
        }
        
        [_pdGui.widgets removeAllObjects];
    }];
}

- (BOOL) loadJSON {
      // patch specification version, incremented on breaking changes.
      // current version is 2, lower versions have old slider range behavior.
      NSUInteger version = [_sceneDict[@"version"] unsignedIntegerValue];
    
      //type of canvas used in the _editor_ to make the interface. If it doesn't match the above
      // hardwareCnvasType, then we will be scaling to fit
      MMPDeviceCanvasType editorCanvasType = canvasTypeWidePhone; //default.
      // include deprecated strings
      if (_sceneDict [@"canvasType"]) {
        NSString *typeString = (NSString*)_sceneDict[@"canvasType"];
        if ([typeString isEqualToString:@"iPhone3p5Inch"] || [typeString isEqualToString:@"widePhone"]) {
          editorCanvasType = canvasTypeWidePhone;
        } else if ([typeString isEqualToString:@"iPhone4Inch"] || [typeString isEqualToString:@"tallPhone"]) {
          editorCanvasType = canvasTypeTallPhone;
        } else if ([typeString isEqualToString:@"android7Inch"] || [typeString isEqualToString:@"tallTablet"]) {
          editorCanvasType = canvasTypeTallTablet;
        } else if ([typeString isEqualToString:@"iPad"] || [typeString isEqualToString:@"wideTablet"]) {
          editorCanvasType = canvasTypeWideTablet;
        }
      }
    
      // get two necessary layout values from the JSON file
      // page count
      _pageCount = 1; //default.
      if (_sceneDict[@"pageCount"]) {
        _pageCount = [_sceneDict[@"pageCount"] intValue];
        if (_pageCount <= 0) {
          _pageCount = 1;
        }
      }
    
      // get orientation and init scrollview
      BOOL isOrientationLandscape = NO; //default.
      if (_sceneDict[@"isOrientationLandscape"]) {
        isOrientationLandscape = [_sceneDict[@"isOrientationLandscape"] boolValue];
      }
    
      //get layout of the scrollview that holds the GUI
      float zoomFactor = 1;
      CGRect scrollViewFrame;
    
      CGSize hardwareCanvasSize;
      if (isOrientationLandscape) {
        hardwareCanvasSize = CGSizeMake([[UIScreen mainScreen] bounds].size.height,
                                        [[UIScreen mainScreen] bounds].size.width);
      } else {
        hardwareCanvasSize = CGSizeMake([[UIScreen mainScreen] bounds].size.width,
                                        [[UIScreen mainScreen] bounds].size.height);
      }
      CGFloat hardwareCanvasRatio = hardwareCanvasSize.width / hardwareCanvasSize.height;
    
      CGSize docCanvasSize;
      CGFloat canvasWidth, canvasHeight;
      CGFloat canvasRatio;
      switch(editorCanvasType) {
        case canvasTypeWidePhone:
          docCanvasSize = isOrientationLandscape ? CGSizeMake(480, 320) : CGSizeMake(320, 480);
          break;
        case canvasTypeTallPhone:
          docCanvasSize = isOrientationLandscape ? CGSizeMake(568, 320) : CGSizeMake(320, 568);
          break;
        case canvasTypeTallTablet:
          docCanvasSize = isOrientationLandscape ? CGSizeMake(950, 600) : CGSizeMake(600, 950);
          break;
        case canvasTypeWideTablet:
          docCanvasSize = isOrientationLandscape ? CGSizeMake(1024, 768) : CGSizeMake(768, 1024);
          break;
      }
    
      canvasRatio = docCanvasSize.width / docCanvasSize.height;
    
      if (canvasRatio > hardwareCanvasRatio) {
        // The doc canvas has a wider aspect ratio than the hardware canvas;
        // It will take the width of the screen and get letterboxed on top.
        zoomFactor = hardwareCanvasSize.width / docCanvasSize.width;
        canvasWidth = hardwareCanvasSize.width ;
        canvasHeight = canvasWidth / canvasRatio;
        scrollViewFrame = CGRectMake(0,
                                     (hardwareCanvasSize.height - canvasHeight) / 2.0f,
                                     canvasWidth,
                                     canvasHeight);
      } else {
        // The doc canvas has a taller aspect ratio thatn the hardware canvas;
        // It will take the height of the screen and get letterboxed on the sides.
        zoomFactor = hardwareCanvasSize.height/ docCanvasSize.height;
        canvasHeight = hardwareCanvasSize.height;
        canvasWidth = canvasHeight * canvasRatio;
        scrollViewFrame = CGRectMake((hardwareCanvasSize.width - canvasWidth) / 2.0f,
                                     0,
                                     canvasWidth,
                                     canvasHeight);
      }
    
      _scrollView = [[UIScrollView alloc]initWithFrame:scrollViewFrame];
      _scrollInnerView = [[UIView alloc]initWithFrame:CGRectMake(0,
                                                                 0,
                                                                 docCanvasSize.width*_pageCount,
                                                                 docCanvasSize.height)];
    
      [_scrollView setContentSize:_scrollInnerView.frame.size];
      [_scrollView addSubview:_scrollInnerView];
    
      if (isOrientationLandscape) { //rotate
        APP.viewController.isLandscape = YES;
        CGPoint rotatePoint =
            CGPointMake(hardwareCanvasSize.height / 2.0f, hardwareCanvasSize.width / 2.0f);
        _scrollView.center = rotatePoint;
        if (APP.viewController.uiIsFlipped) {
          _scrollView.transform = CGAffineTransformMakeRotation(M_PI_2+M_PI);
        } else {
          _scrollView.transform = CGAffineTransformMakeRotation(M_PI_2);
        }
      } else {
        APP.viewController.isLandscape = NO;
        if (APP.viewController.uiIsFlipped) {
          _scrollView.transform = CGAffineTransformMakeRotation(M_PI);
        }
      }
    
      _scrollView.pagingEnabled = YES;
      _scrollView.delaysContentTouches = NO;
      _scrollView.maximumZoomScale = zoomFactor;
      _scrollView.minimumZoomScale = zoomFactor;
      [_scrollView setDelegate:self];
      [self.view addSubview:_scrollView];
    
      // start page
      int startPageIndex = 0;
      if (_sceneDict[@"startPageIndex"]) {
        startPageIndex = [_sceneDict[@"startPageIndex"] intValue];
        //check if beyond pageCount, then set to last page
        if (startPageIndex > _pageCount) {
          startPageIndex = _pageCount - 1;
        }
      }
    
      // bg color
      if (_sceneDict[@"backgroundColor"]) {
        _scrollView.backgroundColor = [MeControl colorFromRGBArray:_sceneDict[@"backgroundColor"]];
//        [_settingsButton setBarColor:[MeControl inverseColorFromRGBArray:_sceneDict[@"backgroundColor"]]];
      } else {
//        [_settingsButton setBarColor:[UIColor whiteColor]]; //default, but shouldn't happen.
      }
    
      if (_sceneDict[@"menuButtonColor"]) {
//        [_settingsButton setBarColor:[MeControl colorFromRGBAArray:_sceneDict[@"menuButtonColor"]]];
      }
    
      // get array of all widgets
      NSArray *controlArray = _sceneDict[@"gui"];
      if (!controlArray) {
        return NO;
      }
    
      // check that it is an array of NSDictionary
      if (controlArray.count > 0 && ![controlArray[0] isKindOfClass:[NSDictionary class]]) {
        return NO;
      }
    
      // step through each gui widget, big loop each time
      for (NSDictionary *currDict in controlArray) {
        MeControl *currObject;
    
        //start with elements common to all widget subclasses
        //frame - if no frame is found, skip this widget
        NSArray *frameRectArray = currDict[@"frame"];
        if (frameRectArray.count != 4) {
          continue;
        }
    
        CGRect frame = CGRectMake([frameRectArray[0] floatValue],
                                  [frameRectArray[1] floatValue],
                                  [frameRectArray[2] floatValue],
                                  [frameRectArray[3] floatValue]);
    
    
        // widget color
        UIColor *color = [UIColor colorWithRed:1 green:1 blue:1 alpha:1]; // default.
        if (currDict[@"color"]) {
          NSArray *colorArray = currDict[@"color"];
          if (colorArray.count == 3) { //old format before translucency
            color = [MeControl colorFromRGBArray:colorArray];
          } else if (colorArray.count == 4) { //newer format including transulcency
            color = [MeControl colorFromRGBAArray:colorArray];
          }
        }
    
        //widget highlight color
        UIColor *highlightColor = [UIColor grayColor]; // default.
        if (currDict[@"highlightColor"]) {
          NSArray *highlightColorArray = currDict[@"highlightColor"];
          if (highlightColorArray.count == 3) {
            highlightColor = [MeControl colorFromRGBArray:highlightColorArray];
          } else if (highlightColorArray.count == 4) {
            highlightColor = [MeControl colorFromRGBAArray:highlightColorArray];
          }
        }
    
        // get the subclass type, and do subclass-specific stuff
        NSString *newObjectClass = currDict[@"class"];
        if (!newObjectClass) {
          continue;
        }
        if ([newObjectClass isEqualToString:@"MMPSlider"]) {
          MeSlider *slider = [[MeSlider alloc] initWithFrame:frame];
          currObject = slider;
          if ([currDict[@"isHorizontal"] boolValue] == YES) {
            [slider setHorizontal];
          }
    
          if (currDict[@"range"]) {
            int range = [currDict[@"range"] intValue];
            if (version < 2) {
              // handle old style of slider ranges.
              [slider setLegacyRange:range];
            } else {
              [slider setRange:range];
            }
          }
        } else if ([newObjectClass isEqualToString:@"MMPKnob"]) {
          MeKnob *knob = [[MeKnob alloc] initWithFrame:frame];
          currObject = knob;
          if (currDict[@"range"]) {
            int range = [currDict[@"range"] intValue];
            if (version < 2) {
              // handle old style of knob ranges.
              [knob setLegacyRange:range];
            } else {
              [knob setRange:range];
            }
          }
          UIColor *indicatorColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
          if (currDict[@"indicatorColor"]) {
            indicatorColor = [MeControl colorFromRGBAArray:currDict[@"indicatorColor"]];
          }
          [knob setIndicatorColor:indicatorColor];
        } else if ([newObjectClass isEqualToString:@"MMPLabel"]) {
          MeLabel *label = [[MeLabel alloc] initWithFrame:frame];
          currObject = label;
    
          if (currDict[@"text"]) {
            label.stringValue = currDict[@"text"];
          }
          if (currDict[@"textSize"]) {
            label.textSize = [currDict[@"textSize"] intValue];
          }
          if (currDict[@"textFont"] && currDict[@"textFontFamily"]) {
            [label setFontFamily:currDict[@"textFontFamily"] fontName:currDict[@"textFont"]];
          }
          if ([currDict[@"hAlign"] isKindOfClass:[NSNumber class]]) {
            label.horizontalTextAlignment = [currDict[@"hAlign"] integerValue];
          }
          if ([currDict[@"vAlign"] isKindOfClass:[NSNumber class]]) {
            label.verticalTextAlignment = [currDict[@"vAlign"] integerValue];
          }
          [label sizeToFit];
        } else if ([newObjectClass isEqualToString:@"MMPButton"]) {
          currObject = [[MeButton alloc] initWithFrame:frame];
        } else if ([newObjectClass isEqualToString:@"MMPToggle"]) {
          MeToggle *toggle = [[MeToggle alloc] initWithFrame:frame];
          currObject = toggle;
          if (currDict[@"borderThickness"]) {
            toggle.borderThickness = [currDict[@"borderThickness"] intValue];
          }
        } else if ([newObjectClass isEqualToString:@"MMPXYSlider"]) {
          currObject = [[MeXYSlider alloc]initWithFrame:frame];
        } else if ([newObjectClass isEqualToString:@"MMPGrid"]) {
          MeGrid *grid = [[MeGrid alloc] initWithFrame:frame];
          currObject = grid;
          if (currDict[@"mode"]) {
            grid.mode = [currDict[@"mode"] intValue]; //needs to be done before setting dim.
          }
          if (currDict[@"dim"]) {
            NSArray *dimArray = currDict[@"dim"];
            if (dimArray.count == 2) {
              [grid setDimX:[dimArray[0] intValue] Y:[dimArray[1] intValue]];
            }
          }
          if (currDict[@"cellPadding"]) {
            grid.cellPadding = [currDict[@"cellPadding"] intValue];
          }
          if (currDict[@"borderThickness"]) {
            grid.borderThickness = [currDict[@"borderThickness"] intValue];
          }
        } else if ([newObjectClass isEqualToString:@"MMPPanel"]) {
          MePanel *panel = [[MePanel alloc] initWithFrame:frame];
          currObject = panel;
          if (currDict[@"imagePath"]) {
            panel.imagePath = currDict[@"imagePath"];
          }
          if (currDict[@"passTouches"]) {
            panel.shouldPassTouches = [currDict[@"passTouches"] boolValue];
          }
        } else if ([newObjectClass isEqualToString:@"MMPMultiSlider"]) {
          MeMultiSlider *multiSlider = [[MeMultiSlider alloc] initWithFrame:frame];
          currObject = multiSlider;
          if (currDict[@"range"]) {
            multiSlider.range = [currDict [@"range"] intValue];
          }
          if (currDict[@"outputMode"]) {
            multiSlider.outputMode = [currDict [@"outputMode"] integerValue];
          }
        } else if ([newObjectClass isEqualToString:@"MMPLCD"]) {
          currObject = [[MeLCD alloc] initWithFrame:frame];
        } else if ([newObjectClass isEqualToString:@"MMPMultiTouch"]) {
          currObject = [[MeMultiTouch alloc] initWithFrame:frame];
        } else if ([newObjectClass isEqualToString:@"MMPMenu"]) {
          MeMenu *menu = [[MeMenu alloc] initWithFrame:frame];
          currObject = menu;
          if (currDict[@"title"]) {
            menu.titleString = currDict[@"title"];
          }
        } else if ([newObjectClass isEqualToString:@"MMPTable"]) {
          MeTable *table = [[MeTable alloc] initWithFrame:frame];
          currObject = table;
          if (currDict[@"mode"]) {
            table.mode = [currDict [@"mode"] intValue];
          }
          if (currDict[@"selectionColor"]) {
            table.selectionColor = [MeControl colorFromRGBAArray:currDict[@"selectionColor"]];
          }
          if (currDict [@"displayRangeLo"]) {
            table.displayRangeLo = [currDict[@"displayRangeLo"] floatValue];
          }
          if (currDict [@"displayRangeHi"]) {
            table.displayRangeHi = [currDict[@"displayRangeHi"] floatValue];
          }
          if (currDict [@"displayMode"]) {
            table.displayMode = [currDict[@"displayMode"] integerValue];
          }
        } else {
          MeUnknown *unknownWidget = [[MeUnknown alloc] initWithFrame:frame];
          currObject = unknownWidget;
          [unknownWidget setWarning:newObjectClass];
        }
        //end subclass-specific list
    
        if (!currObject) { // failed to create object
          continue;
        } else { // if successfully created object
          currObject.controlDelegate = self;
          [currObject setColor:color];
          [currObject setHighlightColor:highlightColor];
    
          // set OSC address for widget
          NSString *address = @"dummy";
          if (currDict[@"address"]) {
            address = currDict[@"address"];
          }
          currObject.address = address;
    
          // Add to address array in _addressToGUIObjectsDict
          NSMutableArray *addressArray = _addressToGUIObjectsDict[currObject.address];
          if (!addressArray) {
            addressArray = [NSMutableArray array];
            _addressToGUIObjectsDict[currObject.address] = addressArray;
          }
          [addressArray addObject:currObject];
    
          [_scrollInnerView addSubview:currObject];
        }
      }
      //end of big loop through widgets
    
    //===PureData patch
      if (_sceneDict[@"pdFile"]) {
        NSString *filename = _sceneDict[@"pdFile"];
    
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *publicDocumentsDir = [paths objectAtIndex:0];
          
          _pdPatch = [PdBase openFile:filename path:publicDocumentsDir];
//        _openPDFile = [PdFile openFileNamed:filename path:publicDocumentsDir];
          _filename = [filename substringToIndex:filename.length-3];
          if (_pdPatch == nil) { //failure to load the named patch
                    NSLog(@"did not find named patch!" );
                    NSString *message =
                        [NSString stringWithFormat:@"Pd file %@ not found, make sure you add it to Documents in iTunes",
                             filename];
                    UIAlertView *alert = [[UIAlertView alloc]
                                          initWithTitle: @"Pd file not found"
                                          message:message
                                          delegate: nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
                    [alert show];
              
                  } else { //success
                    //refresh tables
                    //TODO optimize! make an array of tables only
                    for (NSArray *addressArray in [_addressToGUIObjectsDict allValues]) {
                      for(MeControl *control in addressArray) {
                        if ([control isKindOfClass:[MeTable class]]) {
                          // use set to quash multiple loads of same table/address - not needed in app, but needed in editor.
                          [(MeTable*)control loadTable];
                        }
                      }
                    }
                  }
      }else {//if no JSON entry found for file, say so
              _pdPatch=nil;
              NSLog(@"did not find a patch name!" );
              UIAlertView *alert = [[UIAlertView alloc]
                                    initWithTitle: @"Pd file not specified"
                                    message: @"This interface has not been linked to a Pd file. Add it in the editor!"
                                    delegate: nil
                                    cancelButtonTitle:@"OK"
                                    otherButtonTitles:nil];
              [alert show];
            }
    
      //scroll to start page, and put settings button on top
      [_scrollView zoomToRect:CGRectMake(docCanvasSize.width * startPageIndex,
                                         0,
                                         docCanvasSize.width,
                                         docCanvasSize.height)
                     animated:NO];
    
    [self loadStyle];
    
      return YES;
}

- (BOOL)loadScenePatchOnlyFromPath:(NSString *)fromPath {
    if (!fromPath.length) {
        return NO;
    }
//    [self loadSceneCommonReset];
    //  [_settingsButton setBarColor:[UIColor blackColor]];
    //
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *publicDocumentsDir = [paths objectAtIndex:0];
    NSString *toPath = [publicDocumentsDir stringByAppendingPathComponent:[@"tempPdFile-" stringByAppendingString:[NSString stringWithFormat:@"%d.pd", _sceneArrayIndex]]];
    
    NSArray *originalAtomLines = [PdParser getAtomLines:[PdParser readPatch:fromPath]];
    
    // Detect bad pd file.
    if ([originalAtomLines count] == 0 ||
        [originalAtomLines[0] count] < 6 ||
        ![originalAtomLines[0][1] isEqualToString:@"canvas"] ) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle: @"Pd file not parsed"
                              message: [NSString stringWithFormat:@"Pd file not readable"]
                              delegate: nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    // Process original atom lines into a set of gui lines and a set of shimmed patch lines.
    NSArray *processedAtomLinesTuple = [MMPPdPatchDisplayUtils proccessAtomLines:originalAtomLines];
    if (!processedAtomLinesTuple || processedAtomLinesTuple.count != 2) {
        return NO;
    }
    NSArray *patchAtomLines = processedAtomLinesTuple[0];
    NSArray *guiAtomLines = processedAtomLinesTuple[1];
    
    // Reformat patchAtomLines into a pd file.
    NSMutableString *outputMutableString = [NSMutableString string];
    for (NSArray *line in patchAtomLines) {
        [outputMutableString appendString:[line componentsJoinedByString:@" "]];
        [outputMutableString appendString:@";\n"];
    }
    
    //handle outputString as non-mutable.
    NSString *outputString = (NSString *)outputMutableString;
    
    // Write temp pd file to disk.
    if (![outputString canBeConvertedToEncoding:NSASCIIStringEncoding] ) {
        // Writing to ascii would fail in Automatism patches. Check first and do lossy conversion.
        NSData *asciiData = [outputString dataUsingEncoding:NSASCIIStringEncoding
                                       allowLossyConversion:YES];
        outputString = [[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding];
    }
    
    NSError *error;
    [outputString writeToFile:toPath atomically:YES encoding:NSASCIIStringEncoding error:&error];
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle: @"Pd file not parsed"
                              message: [NSString stringWithFormat:@"Pd file not parseable for native display"]
                              delegate: nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    _filename = [[fromPath lastPathComponent] substringToIndex:[fromPath lastPathComponent].length-3];
    CGSize docCanvasSize = CGSizeMake([originalAtomLines[0][4] floatValue], [originalAtomLines[0][5] floatValue]);
    // TODO check for zero/bad values
    BOOL isOrientationLandscape = (docCanvasSize.width > docCanvasSize.height);
    CGSize hardwareCanvasSize = CGSizeZero;
    if (isOrientationLandscape) {
        hardwareCanvasSize = CGSizeMake([[UIScreen mainScreen] bounds].size.height,
                                        [[UIScreen mainScreen] bounds].size.width);
    } else {
        hardwareCanvasSize = CGSizeMake([[UIScreen mainScreen] bounds].size.width,
                                        [[UIScreen mainScreen] bounds].size.height);
    }
    CGFloat hardwareCanvasRatio = hardwareCanvasSize.width / hardwareCanvasSize.height;
    CGFloat canvasRatio = docCanvasSize.width / docCanvasSize.height;
    
    CGFloat canvasWidth = 0, canvasHeight = 0;
    if (canvasRatio > hardwareCanvasRatio) {
        // The doc canvas has a wider aspect ratio than the hardware canvas;
        // It will take the width of the screen and get letterboxed on top.
        canvasWidth = hardwareCanvasSize.width ;
        canvasHeight = canvasWidth / canvasRatio;
        _pdPatchView = [[UIView alloc] initWithFrame:
                        CGRectMake(0,
                                   (hardwareCanvasSize.height - canvasHeight) / 2.0f,
                                   canvasWidth,
                                   canvasHeight)];
    } else {
        // The doc canvas has a taller aspect ratio thatn the hardware canvas;
        // It will take the height of the screen and get letterboxed on the sides.
        canvasHeight = hardwareCanvasSize.height;
        canvasWidth = canvasHeight * canvasRatio;
        _pdPatchView = [[UIView alloc] initWithFrame:
                        CGRectMake((hardwareCanvasSize.width - canvasWidth) / 2.0f,
                                   0,
                                   canvasWidth,
                                   canvasHeight)];
    }
    
    _pdPatchView.clipsToBounds = YES; // Keep Pd gui boxes rendered within the view.
    _pdPatchView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_pdPatchView];
    
    if (isOrientationLandscape) { //rotate
        APP.viewController.isLandscape = YES;
        _pdPatchView.center =
        CGPointMake(hardwareCanvasSize.height / 2.0f, hardwareCanvasSize.width / 2.0f);
        if (APP.viewController.uiIsFlipped) {
            _pdPatchView.transform = CGAffineTransformMakeRotation(M_PI_2+M_PI);
            _settingsButton.transform = CGAffineTransformMakeRotation(M_PI_2+M_PI);
            _settingsButton.frame =
            CGRectMake(APP.viewController.settingsButtonOffset,
                       self.view.frame.size.height - APP.viewController.settingsButtonOffset - APP.viewController.settingsButtonDim,
                       APP.viewController.settingsButtonDim,
                       APP.viewController.settingsButtonDim);
        } else {
            _pdPatchView.transform = CGAffineTransformMakeRotation(M_PI_2);
            _settingsButton.frame =
            CGRectMake(self.view.frame.size.width - APP.viewController.settingsButtonDim - APP.viewController.settingsButtonOffset,
                       APP.viewController.settingsButtonOffset,
                       APP.viewController.settingsButtonDim,
                       APP.viewController.settingsButtonDim);
            _settingsButton.transform = CGAffineTransformMakeRotation(M_PI_2);
        }
    } else {
        APP.viewController.isLandscape = NO;
        if (APP.viewController.uiIsFlipped) {
            _pdPatchView.transform = CGAffineTransformMakeRotation(M_PI);
            _settingsButton.transform = CGAffineTransformMakeRotation(M_PI);
            _settingsButton.frame =
            CGRectMake(self.view.frame.size.width - APP.viewController.settingsButtonDim - APP.viewController.settingsButtonOffset,
                       self.view.frame.size.height -APP.viewController.settingsButtonDim -APP.viewController.settingsButtonOffset,
                       APP.viewController.settingsButtonDim,
                       APP.viewController.settingsButtonDim);
            
        } else {
            _settingsButton.transform = CGAffineTransformMakeRotation(0);
            _settingsButton.frame =
            CGRectMake(APP.viewController.settingsButtonOffset,
                       APP.viewController.settingsButtonOffset,
                       APP.viewController.settingsButtonDim,
                       APP.viewController.settingsButtonDim);
        }
    }
    //DEI todo update button pos/rot on flipping.
    
    _pdGui.parentViewSize = CGSizeMake(canvasWidth, canvasHeight);
    [_pdGui addWidgetsFromAtomLines:guiAtomLines]; // create widgets first
    
    _pdPatch = [PdBase openFile:[toPath lastPathComponent] path:publicDocumentsDir];
//    _openPDFile = [PdFile openFileNamed:[toPath lastPathComponent] path:publicDocumentsDir]; //widgets get loadbang
//    if (!_openPDFile) {
//        return NO;
//    }
    
    for(Widget *widget in _pdGui.widgets) {
        [widget replaceDollarZerosForGui:_pdGui withInteger:_openPDFile.dollarZero];
        [_pdPatchView addSubview:widget];
    }
    [_pdGui reshapeWidgets];
    
    for(Widget *widget in _pdGui.widgets) {
        [widget setup];
    }
    return YES;
}

- (UIInterfaceOrientation)orientation {
    if (APP.viewController.isLandscape) {
        if (APP.viewController.uiIsFlipped) {
            return UIInterfaceOrientationLandscapeLeft;
        } else {
            return UIInterfaceOrientationLandscapeRight;
        }
    } else {
        if (APP.viewController.uiIsFlipped) {
            return UIInterfaceOrientationPortraitUpsideDown;
        } else {
            return UIInterfaceOrientationPortrait;
        }
    }
}

- (UIColor *)patchBackgroundColor {
  return _scrollView.backgroundColor;
}


#pragma mark - ControlDelegate

//I want to send a message into PD patch from a gui widget
- (void)sendGUIMessageArray:(NSArray *)msgArray {
    [PdBase sendList:msgArray toReceiver:@"fromGUI"];
}

- (void)receiveList:(NSArray *)list fromSource:(NSString *)source {
    if (!list.count) { //guarantee at least one item in array.
        NSLog(@"got zero args from %@", source);
        return; //protect against bad elements that got dropped from array...
    }
    if ([source isEqualToString:@"toGUI"]) {
        NSMutableArray *addressArray = _addressToGUIObjectsDict[list[0]]; // addressArray can be nil.
        for (MeControl *control in addressArray) {
            [control receiveList:[list subarrayWithRange:NSMakeRange(1, [list count]-1)]];
        }
    }
}

@end
