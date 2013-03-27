//
//  LPCViewController.m
//  LPCPort
//
//  Created by Mayank on 12/3/12.
//  Copyright (c) 2012 CCRMA. All rights reserved.
//

#import "LPCViewController.h"
#import "lpc.h"

#define SRATE 44100
Float64 hardwareSampleRate;
#define MAX_SINT32 32767
#define AUDIO_BUFFER_LENGTH 0.01
#define WAVEFORM_DECIMATE_FACTOR 10



@interface LPCViewController ()

@end

@implementation LPCViewController

static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;
	
	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
	fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
	exit(1);
}



#pragma mark callbacks
static void MyInterruptionListener (void *inUserData,
                                    UInt32 inInterruptionState) {
	
	printf ("Interrupted! inInterruptionState=%ld\n", inInterruptionState);
	LPCViewController *lpcController = (__bridge LPCViewController*)inUserData;
	switch (inInterruptionState) {
		case kAudioSessionBeginInterruption:
            break;
		case kAudioSessionEndInterruption:
			// TODO: doesn't work!
			CheckError(AudioSessionSetActive(true),
					   "Couldn't set audio session active");
			CheckError (AudioOutputUnitStart (lpcController.effectState.rioUnit),
						"Couldn't start RIO unit");
            break;
		default:
			break;
	};
}


void audioRouteChangeListenerCallback (
                                       void                   *inUserData,                                 // 1
                                       AudioSessionPropertyID inPropertyID,                                // 2
                                       UInt32                 inPropertyValueSize,                         // 3
                                       const void             *inPropertyValue                             // 4
                                       ) {
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return; // 5
    
    CFDictionaryRef routeChangeDictionary = (CFDictionaryRef)inPropertyValue;        // 8
    CFNumberRef routeChangeReasonRef =
    (CFNumberRef) CFDictionaryGetValue (
                                        routeChangeDictionary,
                                        CFSTR (kAudioSession_AudioRouteChangeKey_Reason)
                                        );
    
    SInt32 routeChangeReason;
    CFNumberGetValue (
                      routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason
                      );
    
    //headphones taken out
    if (routeChangeReason ==
        kAudioSessionRouteChangeReason_OldDeviceUnavailable) {  // 9
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  // 1
        
        AudioSessionSetProperty (
                                 kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                 sizeof (audioRouteOverride),                                      // 3
                                 &audioRouteOverride                                               // 4
                                 );
        
    }
    //headphones plugged
    if (routeChangeReason ==
        kAudioSessionRouteChangeReason_NewDeviceAvailable) {  // 9
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;  // 1
        
        AudioSessionSetProperty (
                                 kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                 sizeof (audioRouteOverride),                                      // 3
                                 &audioRouteOverride                                               // 4
                                 );
        
    }
    
}


static OSStatus GranularSynthRenderCallback (
                                             void *							inRefCon,
                                             AudioUnitRenderActionFlags *	ioActionFlags,
                                             const AudioTimeStamp *			inTimeStamp,
                                             UInt32							inBusNumber,
                                             UInt32							inNumberFrames,
                                             AudioBufferList *				ioData) {
	EffectState *effectState = (EffectState*) inRefCon;
    
	// just copy samples
	UInt32 bus1 = 1;
	CheckError(AudioUnitRender(effectState->rioUnit,
                               ioActionFlags,
                               inTimeStamp,
                               bus1,
                               inNumberFrames,
                               ioData),
			   "Couldn't render from RemoteIO unit");
	// walk the samples
    
    static int sampleCount;
    sampleCount = 0;
    
	AudioSampleType sample = 0;
	UInt32 bytesPerChannel = effectState->asbd.mBytesPerFrame/effectState->asbd.mChannelsPerFrame;
	for (int bufCount=0; bufCount<ioData->mNumberBuffers; bufCount++) {
		AudioBuffer buf = ioData->mBuffers[bufCount];
		int currentFrame = 0;
		while ( currentFrame < inNumberFrames ) {
			// copy sample to buffer, across all channels
			for (int currentChannel=0; currentChannel<buf.mNumberChannels; currentChannel++) {
				memcpy(&sample,(char *)buf.mData + (currentFrame * effectState->asbd.mBytesPerFrame) +
                       (currentChannel * bytesPerChannel),
					   sizeof(AudioSampleType));
				
				//sample access here
                static float sampleFloat[2];
                sampleFloat[currentChannel] = (float)sample / MAX_SINT32; // convert to float for DSP
                static float drySampleFloat;
                drySampleFloat = sampleFloat[currentChannel];
                
                if (currentChannel==0)
                {
                    effectState->buffer[sampleCount++] = drySampleFloat;
                }
                sample = 0;
                //copy sample back
				memcpy((char *)buf.mData + (currentFrame * effectState->asbd.mBytesPerFrame) +
                       (currentChannel * bytesPerChannel),
					   &sample,
					   sizeof(AudioSampleType));
			}
			currentFrame++;
		}
	}
    
	return noErr;
}

-(void)setupAudioSession
{
    CheckError(AudioSessionInitialize(NULL,
                                      kCFRunLoopDefaultMode,
                                      MyInterruptionListener,
                                      (__bridge void *)(self)),
               "couldn't initialize audio session");
    
    UInt32 category = kAudioSessionCategory_PlayAndRecord;
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                       sizeof(category),
                                       &category),
               "Couldn't set category on audio session");
    
    // route audio to bottom speaker for iphone
    
    if ([[UIDevice currentDevice].model isEqualToString:@"iPhone"])
    {
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  // 1
        
        AudioSessionSetProperty (
                                 kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                 sizeof (audioRouteOverride),                                      // 3
                                 &audioRouteOverride                                               // 4
                                 );
        
        
        AudioSessionPropertyID routeChangeID =
        kAudioSessionProperty_AudioRouteChange;    // 1
        AudioSessionAddPropertyListener (                                  // 2
                                         routeChangeID,                                                 // 3
                                         audioRouteChangeListenerCallback,                                      // 4
                                         nil                                                       // 5
                                         );
        
        
    }
    
    Float32 preferredBufferDuration = 0.01;                      // 1
    CheckError(AudioSessionSetProperty (                                     // 2
                                        kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                                        sizeof (preferredBufferDuration),
                                        &preferredBufferDuration
                                        ),
               "couldn't set buffer duration");
    
    
    Float64 hwSampleRate = SRATE;
    UInt32 propSize = sizeof (hwSampleRate);
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate,
                                       propSize,
                                       &hwSampleRate),
               "Couldn't set hardwareSampleRate");
    
    // is audio input available?
    UInt32 ui32PropertySize = sizeof (UInt32);
    UInt32 inputAvailable;
    CheckError(AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable,
                                       &ui32PropertySize,
                                       &inputAvailable),
               "Couldn't get current audio input available prop");
    if (! inputAvailable) {
        UIAlertView *noInputAlert =
        [[UIAlertView alloc] initWithTitle:@"No audio input"
                                   message:@"No audio input device is currently attached"
                                  delegate:nil
                         cancelButtonTitle:@"OK"
                         otherButtonTitles:nil];
        [noInputAlert show];
        // TODO: do we have to die? couldn't we tolerate an incoming connection
        // TODO: need another example to show audio routes?
    }
    
    // inspect the hardware input rate
    
    propSize = sizeof (hardwareSampleRate);
    CheckError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                                       &propSize,
                                       &hardwareSampleRate),
               "Couldn't get hardwareSampleRate");
    NSLog (@"hardwareSampleRate = %f", hardwareSampleRate);
    
    //    NSAssert(hardwareSampleRate == SRATE, "sample rate 44100 not supported");
    //	CheckError(AudioSessionSetActive(true),
    //			   "Couldn't set AudioSession active");
    
    // describe unit
    AudioComponentDescription audioCompDesc;
    audioCompDesc.componentType = kAudioUnitType_Output;
    audioCompDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioCompDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioCompDesc.componentFlags = 0;
    audioCompDesc.componentFlagsMask = 0;
    
    // get rio unit from audio component manager
    AudioComponent rioComponent = AudioComponentFindNext(NULL, &audioCompDesc);
    CheckError(AudioComponentInstanceNew(rioComponent, &_effectState.rioUnit),
               "Couldn't get RIO unit instance");
    
    // set up the rio unit for playback
    UInt32 oneFlag = 1;
    AudioUnitElement bus0 = 0;
    CheckError(AudioUnitSetProperty (_effectState.rioUnit,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Output,
                                     bus0,
                                     &oneFlag,
                                     sizeof(oneFlag)),
               "Couldn't enable RIO output");
    
    // enable rio input
    AudioUnitElement bus1 = 1;
    CheckError(AudioUnitSetProperty(_effectState.rioUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    bus1,
                                    &oneFlag,
                                    sizeof(oneFlag)),
               "Couldn't enable RIO input");
    
    
    // setup an asbd in the iphone canonical format
    AudioStreamBasicDescription myASBD;
    memset (&myASBD, 0, sizeof (myASBD));
    myASBD.mSampleRate = hardwareSampleRate;
    myASBD.mFormatID = kAudioFormatLinearPCM;
    myASBD.mFormatFlags = kAudioFormatFlagsCanonical;
    myASBD.mBytesPerPacket = 4;
    myASBD.mFramesPerPacket = 1;
    myASBD.mBytesPerFrame = 4;
    myASBD.mChannelsPerFrame = 2;
    myASBD.mBitsPerChannel = 16;
    
    /*
     // set format for output (bus 0) on rio's input scope
     */
    CheckError(AudioUnitSetProperty (_effectState.rioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input,
                                     bus0,
                                     &myASBD,
                                     sizeof (myASBD)),
               "Couldn't set ASBD for RIO on input scope / bus 0");
    
    
    // set asbd for mic input
    CheckError(AudioUnitSetProperty (_effectState.rioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     bus1,
                                     &myASBD,
                                     sizeof (myASBD)),
               "Couldn't set ASBD for RIO on output scope / bus 1");
    
    _effectState.asbd = myASBD;
    
    // set callback method
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = GranularSynthRenderCallback; // callback function
    callbackStruct.inputProcRefCon = &_effectState;
    
    CheckError(AudioUnitSetProperty(_effectState.rioUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Global,
                                    bus0,
                                    &callbackStruct,
                                    sizeof (callbackStruct)),
               "Couldn't set RIO render callback on bus 0");
    // initialize and start remoteio unit
    CheckError(AudioUnitInitialize(_effectState.rioUnit),
               "Couldn't initialize RIO unit");
    //    CheckError(AudioUnitInitialize(_effectState.inputEQ),
    //			   "Couldn't initialize inputEQ unit");
    CheckError (AudioOutputUnitStart (_effectState.rioUnit),
                "couldn't start RIO unit");
    
    
    printf("RIO started!\n");
    
    _effectState.lpc = lpc_create();
    
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self setupAudioSession];
    
    self.waveView->lengthBuffer = new int;
    *self.waveView->lengthBuffer = 256;
    
    self.waveView->buffer = new float[256];
    _effectState.buffer = self.waveView->buffer;
    
    self.waveView->residue = new float[256];
    _effectState.residue = self.waveView->buffer;
    
    
    for (int i=0;i<*self.waveView->lengthBuffer;i++)
        self.waveView->buffer[i] = 0.5;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseGL) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeGL) name:UIApplicationDidBecomeActiveNotification object:nil];
    
}


-(void)pauseGL
{
    self.waveView->displayLink.paused = YES;
}

-(void)resumeGL
{
    self.waveView->displayLink.paused = NO;
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
