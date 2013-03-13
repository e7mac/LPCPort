//
//  WaveformView.h
//  PediPadProc
//
//  Created by Mayank on 9/13/12.
//  Copyright (c) 2012 Mayank, Kurt. All rights reserved.
//

typedef struct {
    float Position[3];
    float Color[4];
} Vertex;

#import "DefaultGLView.h"
#import "lpc.h"

@interface WaveformView : DefaultGLView {
@public
    float *buffer;
    int *lengthBuffer;
    float *residue;
@private
    lpc_data lpc;
    float coefs[1024];
    float radii[1024];
    int order;
    float power;
    float pitch;
}

@property float step;

@end
