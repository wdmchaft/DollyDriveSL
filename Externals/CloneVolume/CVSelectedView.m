/*
 *  CVSelectedView.m
 *  CloneVolume
 *
 *  Created by Pumptheory P/L on 13/01/11.
 *  Copyright 2011 Pumptheory P/L. All rights reserved.
 *
 */

#import "CVSelectedView.h"

@implementation CVSelectedView

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect r = [self bounds];
  
  r = NSInsetRect (r, 3, 3);

  [NSGraphicsContext saveGraphicsState];
  NSSetFocusRingStyle (NSFocusRingAbove);
  NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:r];
  [[NSColor colorWithCalibratedWhite:.78 alpha:1.0] setFill];
  [path fill];
  [NSGraphicsContext restoreGraphicsState];  
}

@end

