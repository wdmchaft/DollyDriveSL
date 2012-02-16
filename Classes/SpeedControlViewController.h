//
//  SpeedControlViewController.h
//  DollyDriveApp
//
//  Created by Angelone John on 10/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MGAViewController.h"
#import <Cocoa/Cocoa.h>

@class TMSliderControl;

@interface SpeedControlViewController : MGAViewController
{
    IBOutlet TMSliderControl* throttleOnOffSlider;
    IBOutlet NSButton *throttleOnButton;
    IBOutlet NSButton *throttleOffButton;
    IBOutlet NSSlider *bandwidthThrottle;
    IBOutlet NSTextField *bandwidthLabel;
    IBOutlet NSTabView *tabview;
    BOOL throttleOn;
}

@property (assign) BOOL throttleOn;
@property (retain)  NSSlider *bandwidthThrottle;
@property (assign) NSTextField *bandwidthLabel;
@property (assign)  NSTabView *tabview;


- (IBAction)throttleChange:(id)sender;
- (IBAction)throttleSliderChanged:(id)sender;
- (void) showThrottleSpeed:(float)throttle;

- (void) loadSettings;
- (NSView*)tabView;

@end
