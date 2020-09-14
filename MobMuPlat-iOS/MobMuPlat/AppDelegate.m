//
//  AppDelegate.m
//  MobMuPlat
//
//  Created by Daniel Iglesia on 11/15/12.
//  Copyright (c) 2012 Daniel Iglesia. All rights reserved.
//

#import "AppDelegate.h"

#import "MMPViewController.h"
#import "ZipArchive.h"
#import "SplashViewController.h"

@implementation AppDelegate {
    
    ABLLinkRef linkRef_;
    
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    linkRef_ = ABLLinkNew(120);
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    //intro splash
    SplashViewController* splashController = [[SplashViewController alloc]init];
    splashController.delegate=self;
    [self.window setRootViewController:splashController];
    [splashController launchSplash];
   
    //main VC - loads and then is set as rootVC when splash is finished
    self.viewController = [[MMPViewController alloc] init];
    
    [self.window makeKeyAndVisible];
    
    return YES;
}


-(void)dismissSplash{
    [self.window setRootViewController:self.viewController];
}

//app opened with file
-(BOOL) application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [self getFileFromURL:url];
}

//MobMuPlat is associated with .pd, .mmp, and .zip files. This handles importing those files into the Documents folder
-(BOOL)getFileFromURL:(NSURL*)url{
    if([url.absoluteString isEqualToString:@"MobMuPlat.audiobus://"] ||
       [url.absoluteString isEqualToString:@"MobMuPlat-v2.audiobus://"]) {
      return YES;//it sends this on connection to audiobus
    }

    [self handleFileFromUrl:url];
    
        
    return YES;

}

- (void) handleFileFromUrl: (NSURL*) url {
    NSString* filename = [[url path] lastPathComponent];
      NSString *suffix = [[filename componentsSeparatedByString:@"."] lastObject];
      
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      NSString *publicDocumentsDir = [paths objectAtIndex:0];
      
      //if a zip, unpack to documents, and overwrite all files with same name, then delete the zip
      if([suffix isEqualToString:@"zip"]){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          ZipArchive* za = [[ZipArchive alloc] init];
          
          if( [za UnzipOpenFile:[url path]] ) {
              if( [za UnzipFileTo:publicDocumentsDir overWrite:YES] != NO ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  UIAlertView *alert = [[UIAlertView alloc]
                                        initWithTitle: @"Archive Decompressed"
                                        message: [NSString stringWithFormat:@"Decompressed contents of %@ to MobMuPlat Documents", filename]
                                        delegate: nil
                                        cancelButtonTitle:@"OK"
                                        otherButtonTitles:nil];
                  [alert show];
                  NSError* error;
                  #if TARGET_OS_MACCATALYST
                  #else
                  [[NSFileManager defaultManager]removeItemAtURL:url error:&error];//delete the orig zip file
                    #endif
                  [[self.viewController settingsVC] reloadFileTable];
                });

              }
              else{
                dispatch_async(dispatch_get_main_queue(), ^{
                  UIAlertView *alert = [[UIAlertView alloc]
                                        initWithTitle: @"Archive Failure"
                                        message: [NSString stringWithFormat:@"Could not decompress contents of %@", filename]
                                        delegate: nil
                                        cancelButtonTitle:@"OK"
                                        otherButtonTitles:nil];
                  [alert show];
                });
              }
              
              [za UnzipCloseFile];
          }
        });
      }
    
      else{//not zip - manually overwrite file
      
          NSError *error;
          
          NSString* dstPath = [publicDocumentsDir stringByAppendingPathComponent:filename];
          if([[NSFileManager defaultManager] fileExistsAtPath:dstPath]) [[NSFileManager defaultManager] removeItemAtPath:dstPath error:&error];

            #if TARGET_OS_MACCATALYST
          BOOL moved = [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:dstPath] error:&error];
            #else
          BOOL moved = [[NSFileManager defaultManager]moveItemAtURL:url toURL:[NSURL fileURLWithPath:dstPath] error:&error];
            #endif
                 
          if(moved){
              UIAlertView *alert = [[UIAlertView alloc]
                            initWithTitle: @"File Copied"
                            message: [NSString stringWithFormat:@"Copied %@ to MobMuPlat Documents", filename]
                            delegate: nil
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
              [alert show];
                #if TARGET_OS_MACCATALYST
                #else
              [[NSFileManager defaultManager]removeItemAtURL:url error:&error];//delete original
                #endif
              [[self.viewController settingsVC] reloadFileTable];
              
          }
          else{
              UIAlertView *alert = [[UIAlertView alloc]
                                    initWithTitle: @"File not copied"
                                    message: [NSString stringWithFormat:@"Could not copy %@ to MobMuPlat Documents", filename]
                                    delegate: nil
                                    cancelButtonTitle:@"OK"
                                    otherButtonTitles:nil];
              [alert show];
          }
      }
}

- (void)applicationWillResignActive:(UIApplication *)application {

  [self.viewController applicationWillResignActive];

}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
  [self.viewController applicationDidBecomeActive];
  
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  [[NSUserDefaults standardUserDefaults] synchronize];
  [self.viewController disconnectPorts];
    
    ABLLinkDelete(linkRef_);
}

- (ABLLinkRef)getLinkRef {
    return linkRef_;
}

@end
