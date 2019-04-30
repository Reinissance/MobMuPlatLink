//
//  MobMuPlatPdAudioUnit.m
//  MobMuPlat
//
//  Created by diglesia on 1/19/15.
//  Copyright (c) 2015 Daniel Iglesia. All rights reserved.
//

#import "MobMuPlatPdLinkAudioUnit.h"

#import "AudioHelpers.h"
#import "PdBase.h"
#include <AVFoundation/AVFoundation.h>
#include <mach/mach_time.h>

#include "abl_link.c"  // Yes, we want to include the .c file here.

static const AudioUnitElement kOutputElement = 0;

static int kPdBlockSize;

@interface MobMuPlatPdLinkAudioUnit () {
@private
    Float64 sampleRate_;
    int numChannels_;
    BOOL usesInput_;
    UInt32 outputLatency_;
    UInt32 tickTime_;
    ABLLinkRef linkRef_;
}

- (void)handleRouteChange:(NSNotification *)notification;
@end

@implementation MobMuPlatPdLinkAudioUnit {
  BOOL _inputEnabled;
  int _blockSizeAsLog;
}

#pragma mark - Init / Dealloc

+ (void)initialize {
    // Make sure to initialize PdBase before we do anything else.
    kPdBlockSize = [PdBase getBlockSize];
    abl_link_tilde_setup();
}

- (void)handleRouteChange:(NSNotification *)notification {
    NSLog(@"Route changed.");
    // Redoing the configuration will update output latency and related parameters.
    if ([self configureWithSampleRate:sampleRate_ numberChannels:numChannels_ inputEnabled:usesInput_] != 0) {
        NSLog(@"Failed to recreate audio unit on audio route change.");
    }
}

- (id)initWithLinkRef:(ABLLinkRef)linkRef {
    self = [super init];
    linkRef_ = linkRef;
    abl_link_set_link_ref(linkRef);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    return self;
}

#pragma mark - Public Methods
- (void)setActive:(BOOL)active {
        ABLLinkSetActive(linkRef_, active);
    [super setActive:active];
}

 - (int)configureWithSampleRate:(Float64)sampleRate numberChannels:(int)numChannels inputEnabled:(BOOL)inputEnabled {
     _blockSizeAsLog = log2int([PdBase getBlockSize]);
     _inputEnabled = inputEnabled;
 sampleRate_ = sampleRate;
 numChannels_ = numChannels;
 usesInput_ = inputEnabled;
 mach_timebase_info_data_t timeInfo;
 mach_timebase_info(&timeInfo);
 float secondsToHostTime = (1.0e9 * timeInfo.denom) / (Float64)timeInfo.numer;
 outputLatency_ = (UInt32)(secondsToHostTime * [AVAudioSession sharedInstance].outputLatency);
     tickTime_ = (UInt32)(secondsToHostTime * kPdBlockSize / sampleRate);
 return [super configureWithSampleRate:sampleRate numberChannels:numChannels inputEnabled:inputEnabled];
 }

#pragma mark - AURenderCallback

static const AudioUnitElement kInputElement = 1;

static OSStatus AudioRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {

  MobMuPlatPdLinkAudioUnit *mmppdAudioUnit = (__bridge MobMuPlatPdLinkAudioUnit *)inRefCon;
    Float32 *auBuffer = (Float32 *)ioData->mBuffers[0].mData;
    
  // Original logic.
  /*Float32 *auBuffer = (Float32 *)ioData->mBuffers[0].mData;
  if (mmppdAudioUnit->_inputEnabled) {
    AudioUnitRender(mmppdAudioUnit.audioUnit, ioActionFlags, inTimeStamp, kInputElement, inNumberFrames, ioData);
  }
  int ticks = inNumberFrames >> mmppdAudioUnit->_blockSizeAsLog; // this is a faster way of computing (inNumberFrames / blockSize)
  [PdBase processFloatWithInputBuffer:auBuffer outputBuffer:auBuffer ticks:ticks];
  return noErr;*/

  AudioTimeStamp timestamp = *inTimeStamp;
  if ( ABReceiverPortIsConnected(mmppdAudioUnit->_inputPort) ) {
    // Receive audio from Audiobus, if connected. Note that we also fetch the timestamp here, which is
    // useful for latency compensation, where appropriate.
    ABReceiverPortReceive(mmppdAudioUnit->_inputPort, nil, ioData, inNumberFrames, &timestamp);
  } else {
    // Receive audio from system input otherwise
    if (mmppdAudioUnit->_inputEnabled) {
      AudioUnitRender(mmppdAudioUnit.audioUnit, ioActionFlags, inTimeStamp, kInputElement, inNumberFrames, ioData);
    }
  }

  int ticks = inNumberFrames >> mmppdAudioUnit->_blockSizeAsLog; // this is a faster way of computing (inNumberFrames / blockSize)

    ABLLinkTimelineRef timeline = ABLLinkCaptureAudioTimeline(mmppdAudioUnit->linkRef_);
    abl_link_set_timeline(timeline);
//    int tickks = inNumberFrames / kPdBlockSize;
    UInt64 hostTimeAfterTick = inTimeStamp->mHostTime + mmppdAudioUnit->outputLatency_;
    int bufSizePerTick = kPdBlockSize * mmppdAudioUnit->numChannels_;
    for (int i = 0; i < ticks; i++) {
        hostTimeAfterTick += mmppdAudioUnit->tickTime_;
        abl_link_set_time(hostTimeAfterTick);
        [PdBase processFloatWithInputBuffer:auBuffer outputBuffer:auBuffer ticks:1];
        auBuffer += bufSizePerTick;
    }
    ABLLinkCommitAudioTimeline(mmppdAudioUnit->linkRef_, timeline);
   
//  [PdBase processFloatWithInputBuffer:auBuffer outputBuffer:auBuffer ticks:ticks];

  return noErr;
}


- (AURenderCallback)renderCallback {
  return AudioRenderCallback;
}
/*
- (int)configureWithSampleRate:(Float64)sampleRate numberChannels:(int)numChannels inputEnabled:(BOOL)inputEnabled {
  _blockSizeAsLog = log2int([PdBase getBlockSize]);
  _inputEnabled = inputEnabled;
  return [super configureWithSampleRate:sampleRate numberChannels:numChannels inputEnabled:inputEnabled];
}
*/

@end
