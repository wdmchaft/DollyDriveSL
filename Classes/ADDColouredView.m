//
//  ADDColouredView.m
//  DollyDriveApp
//
//  Created by Alan Rogers on 9/04/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADDColouredView.h"


@implementation ADDColouredView

@synthesize backgroundColour = _backgroundColour;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) 
    {
        _backgroundColour = [NSColor clearColor];
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [NSGraphicsContext saveGraphicsState];
    [self.backgroundColour set];
    
    [NSBezierPath fillRect:dirtyRect];
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)dealloc
{
    [_backgroundColour release], _backgroundColour = nil;
    
    [super dealloc];
}

@end
