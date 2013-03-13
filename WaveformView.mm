//
//  WaveformView.m
//  PediPadProc
//
//  Created by Mayank on 9/13/12.
//  Copyright (c) 2012 Mayank, Kurt. All rights reserved.
//

#import "WaveformView.h"

void real_peel( float * coef, int order, float * radii )
{
    int i,j;
    float rs, temp, tempcoeffs1[1024], tempcoeffs2[1024], reflections[1024];
    
    tempcoeffs1[0] = 1.0f;
    
    // initialize
    for( i = 0; i < order; i++ )
        tempcoeffs1[i+1] = -coef[i];
    
    for( i = 0; i < order; i++ )
    {
        for( j = 0; j <= order-i; j++ ) tempcoeffs2[order-i-j] = tempcoeffs1[j];
        reflections[i] = tempcoeffs2[0];
        rs = 1.0f - reflections[i]*reflections[i];
        if( rs <= 0.0f ) rs = 10000.0f; else rs = 1.0f / rs;
        for( j = 0; j < order-i; j++ )
            tempcoeffs1[j] = (tempcoeffs1[j] - reflections[i] * tempcoeffs2[j]) * rs;
    }
    
    radii[0] = 1.0f;
    for( i = 0; i <= order; i++ )
        radii[i+1] = radii[i] * sqrt((1-reflections[i])/(1.0f + reflections[i]));
    for( i = 0; i <= order; i++ )
        radii[i] = radii[i] / radii[order];
    for( i = 0; i <= order/2; i++ )
    {
        temp = radii[i];
        radii[i] = radii[order-i];
        radii[order-i] = temp;
    }
    radii[0] = .5f;
    //for( i = 0; i < order; i++ )
    //    printf("%f ",radii[i]);
    
    //printf("\n");
    //fflush(stdout);
}



@interface WaveformView()
{
    GLuint vertexBuffer,indexBuffer;
}
@end

Vertex Vertices[1024]; // max lpc length
GLint Indices[1024];

@implementation WaveformView


- (void)setupVBOs {
    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STREAM_DRAW);
    
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STREAM_DRAW);
}

- (void)refreshVBOs {
    
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(Vertices), Vertices);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, sizeof(Indices), Indices);
}

-(void)deleteVBOs
{
    glDeleteBuffers(1, &vertexBuffer);
    glDeleteBuffers(1, &indexBuffer);
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupVBOs];
        [self setupMSAA];
        lpc = lpc_create();
        order = 40;
    }
    
    return self;
}

- (void)dealloc
{
    [self deleteVBOs];
}


- (void)render:(CADisplayLink*)displayLink {
    
    [EAGLContext setCurrentContext:_context];
    // set up stuffs 
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    glBindFramebuffer(GL_FRAMEBUFFER, msaaFramebuffer);
    glClearColor(0.2,0.2,0.2,1.0);
    glClear(GL_COLOR_BUFFER_BIT); // clear things

    glLineWidth(3.0);
    
    // LPC Math
    int length = *lengthBuffer;//sizeof(buffer)/sizeof(float);
    
    lpc_analyze(lpc, buffer, length, coefs, order, &power, &pitch, residue);
    
    
    real_peel( coefs, order, radii );

    // draw top half of vocal tract 
    float x = -1;
    float y = 0;
    int vertexCount = 0;
    int indexCount = 0;

    float step = 2.0f / (order-1);

    for (int i=0;i<order;i++)
    {
        y = radii[i]*0.6;
        
        Indices[indexCount++] = vertexCount;
        
        // add triples (x,y,z) and quads (r,g,b,a) representing this point and its mirror to the list of vertices
        Vertices[vertexCount].Position[0] = x; // x - upper vertex
        Vertices[vertexCount].Position[1] = y; // y
        Vertices[vertexCount].Position[2] = 0; // z
        Vertices[vertexCount].Color[0] = 1; // r - color
        Vertices[vertexCount].Color[1] = 1; // g
        Vertices[vertexCount].Color[2] = 1; // b
        Vertices[vertexCount].Color[3] = 1;
        vertexCount++;
        x += step;
    }
        
    [self refreshVBOs];
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) * 3));
    glDrawElements(GL_LINE_STRIP, order,
                   GL_UNSIGNED_INT, 0);
    
    
    // draw bottom half of LPC
    x = -1;
    y = 0;
    vertexCount = 0;
    indexCount = 0;
    
    step = 2.0f / (order-1);
    
    for (int i=0;i<order;i++)
    {
        y = -radii[i]*0.6;
        
        Indices[indexCount++] = vertexCount;
        
        // add triples (x,y,z) and quads (r,g,b,a) representing this point and its mirror to the list of vertices
        Vertices[vertexCount].Position[0] = x; // x - upper vertex
        Vertices[vertexCount].Position[1] = y; // y
        Vertices[vertexCount].Position[2] = 0; // z
        Vertices[vertexCount].Color[0] = 1; // r - color
        Vertices[vertexCount].Color[1] = 1; // g
        Vertices[vertexCount].Color[2] = 1; // b
        Vertices[vertexCount].Color[3] = 1;
        vertexCount++;
        x += step;
    }
    
    [self refreshVBOs];
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) * 3));
    glDrawElements(GL_LINE_STRIP, order,
                   GL_UNSIGNED_INT, 0);

    // draw residue
    x = -1;
    y = 0;
    vertexCount = 0;
    indexCount = 0;
    
    step = 2.0f / (*lengthBuffer-1);
    
    for (int i=0;i<*lengthBuffer;i++)
    {
        y = residue[i]*0.6;
        Indices[indexCount++] = vertexCount;
        
        // add triples (x,y,z) and quads (r,g,b,a) representing this point and its mirror to the list of vertices
        Vertices[vertexCount].Position[0] = x; // x - upper vertex
        Vertices[vertexCount].Position[1] = y; // y
        Vertices[vertexCount].Position[2] = 0; // z
        Vertices[vertexCount].Color[0] = 1; // r - color
        Vertices[vertexCount].Color[1] = 1; // g
        Vertices[vertexCount].Color[2] = 1; // b
        Vertices[vertexCount].Color[3] = 1;
        vertexCount++;
        x += step;
    }
    
    [self refreshVBOs];
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) * 3));
    glDrawElements(GL_LINE_STRIP, *lengthBuffer,
                   GL_UNSIGNED_INT, 0);

    
    // common drawing things
    
    glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, msaaFramebuffer);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, _framebuffer);
    
    glResolveMultisampleFramebufferAPPLE();
    // render buffer
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    glFlush();
}

- (void)setupDisplayLink {
    
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    displayLink.frameInterval = 4;
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
}


@end
