//
//  SpeedControlViewController.m
//  DollyDriveApp
//
//  Created by Angelone John on 10/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "SpeedControlViewController.h"
#import "ADDAppConfig.h"
#import "ADDServerConfig.h"
#import "ADDLaunchDManagement.h"

@implementation SpeedControlViewController
@synthesize bandwidthThrottle, throttleOn, bandwidthLabel, tabview;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        [self loadSettings];
    }
    
    return self;
}

- (void) loadSettings
{
    NSDictionary *throttleConfig = [NSDictionary dictionaryWithContentsOfFile:[ADDServerConfig throttleConfigPath]];
    NSLog(@"Throttle Config = %@", throttleConfig);
    NSString *speed = [throttleConfig objectForKey:@"speed"];
    BOOL throttleOn = [[throttleConfig objectForKey:@"throttleOn"] boolValue];
    //throttleOn = (BOOL)[NSNumber numberWithBool:state];
    [throttleOnOffSlider setState:throttleOn];
    
    float throttle = [speed floatValue];
    int tick = 0;
    if (throttle == 256)
    {
        tick = 0;
    }
    //else if (throttle == 10241)
    //{
    //    tick = [bandwidthThrottle maxValue];
    //}
    else
    {
        tick = throttle / 512;
    }
    
    [bandwidthThrottle setIntegerValue:tick];
    [self throttleChange:self];
    [self showThrottleSpeed:[speed floatValue]];
}

- (NSTabView*)tabView
{
    return self.tabview;
}

-(IBAction)throttleSliderChanged:(id)sender
{    
    throttleOn = [throttleOnOffSlider state];
    [self throttleChange:self];
}

- (IBAction)throttleChange:(id)sender
{
    ADDLaunchDManagement *launchDMgmt = [[[ADDLaunchDManagement alloc] init] autorelease];
    NSInteger tick = [bandwidthThrottle integerValue];
    
    float throttle = 0;
    switch (tick)
    {
        case 0:
            throttle = 256;
            break;
            
        //case 22:
        //    throttle = 10241;
        //    break;
        default:
            throttle = tick * 512;
    }
    
    
    NSString *speed = [NSString stringWithFormat: @"%1.0f", throttle]; 
    
    [self showThrottleSpeed:throttle];
    NSDictionary *config = [ADDServerConfig plistDictionaryForThrottlerConfigWithSpeed:speed andState:throttleOn]; 
    
    [launchDMgmt unloadThrottlerLaunchDaemon];
    
    [config  writeToFile:[ADDServerConfig throttleConfigPath] atomically:YES];
    
    [launchDMgmt loadThrottlerLaunchDaemon];
    
}


- (void) showThrottleSpeed:(float)throttle
{
    NSString *numberString;
    
    if (throttle == 10241)
    {
        [bandwidthLabel setStringValue:[NSString stringWithFormat:@"Unlimited"]];
    }
    else
    {
        NSString *formatString; 
        if (throttle >= 1024)
        {
            throttle = throttle / 1024;
            numberString = [NSString stringWithFormat: @"%1.1f", throttle];
            formatString = @"%@ Mbps";
        }
        else
        {
            numberString = [NSString stringWithFormat: @"%1.0f", throttle];
            formatString = @"%@ Kbps";
        }        
        [bandwidthLabel setStringValue:[NSString stringWithFormat:formatString, numberString]];
    }
}

@end
