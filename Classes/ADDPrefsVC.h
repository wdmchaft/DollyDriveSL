//
//  ADDPrefsVC.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 23/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MGAViewController.h"
#import <Sparkle/SUUpdater.h>

@interface ADDPrefsVC : MGAViewController
{
    SUUpdater *updater;
}

@property (retain) SUUpdater *updater;

- (IBAction)restoreTMPlist:(id)sender;
- (IBAction)changeUser:(id)sender;

@end
