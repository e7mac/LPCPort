//
//  LPCViewController.h
//  LPCPort
//
//  Created by Mayank on 12/3/12.
//  Copyright (c) 2012 CCRMA. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "WaveformView.h"
#import "lpc.h"

typedef struct {
	AudioUnit rioUnit;
	AudioStreamBasicDescription asbd;
    AudioUnit inputEQ;
    
    float *buffer;
    float *residue;
    lpc_data lpc;
    
    
} EffectState;

@interface LPCViewController : UIViewController

@property (assign) EffectState effectState;
@property (strong, nonatomic) IBOutlet WaveformView *waveView;

@end
