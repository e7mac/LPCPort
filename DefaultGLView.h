//
//  PediPadProcGLView.h
//  PediPadProc
//
//  Created by Mayank on 9/13/12.
//  Copyright (c) 2012 Mayank, Kurt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
//#include <OpenGLES/ES2/glext.h>

@interface DefaultGLView : UIView {
@public
    CAEAGLLayer* _eaglLayer;
    EAGLContext* _context;
    GLuint _colorRenderBuffer;
    GLuint _framebuffer;
    
    //msaa
    GLuint msaaFramebuffer,
    msaaRenderBuffer,
    msaaDepthBuffer;
    
    GLuint _positionSlot;
    GLuint _colorSlot;
    CADisplayLink *displayLink;
}

-(void)setupMSAA;

@end
