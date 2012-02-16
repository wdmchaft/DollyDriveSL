//
//  ADDClickableTextField.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 23/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDClickableTextField.h"

// nice simple idea from our very own Peter N Lewis:
// http://www.cocoabuilder.com/archive/cocoa/222029-how-can-use-nstextfield-like-button.html#222519

@implementation ADDClickableTextField

- (void)mouseDown:(NSEvent *)theEvent;
{
    [self sendAction:[self action] to:[self delegate]];
}

@end
