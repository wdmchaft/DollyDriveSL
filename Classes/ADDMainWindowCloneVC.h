//
//  ADDMainWindowCloneView.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 14/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "MGAViewController.h"
#import "ADDCloneWindowController.h"

@interface ADDMainWindowCloneVC : MGAViewController <ADDCloneWindowDelegate>
{
    ADDCloneWindowController *_cloneWindowController;
}

@property (readonly, retain) ADDCloneWindowController *cloneWindowController;

- (IBAction)newClone:(id)sender;
- (IBAction)updateClone:(id)sender;

- (BOOL)cloneWindowVisible;

@end