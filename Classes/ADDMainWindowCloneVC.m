//
//  ADDMainWindowCloneView.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 14/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDMainWindowCloneVC.h"
#import "CVMainController.h"

@implementation ADDMainWindowCloneVC

- (ADDCloneWindowController*)cloneWindowController
{
    if (_cloneWindowController == nil)
    {
        _cloneWindowController = [[ADDCloneWindowController alloc] init];
        self.cloneWindowController.delegate = self;
        
        [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignMainNotification 
                                                          object:self.cloneWindowController.window 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification * note){
            [self willChangeValueForKey:@"cloneWindowVisible"];
            [self didChangeValueForKey:@"cloneWindowVisible"];
        }
        ];
    } 
    return _cloneWindowController;
}

- (IBAction)newClone:(id)sender
{
    [self willChangeValueForKey:@"cloneWindowVisible"];
    //[self.cloneWindowController setIncremental:NO];
    [self.cloneWindowController showNewClone];
    [self didChangeValueForKey:@"cloneWindowVisible"];
}

- (IBAction)updateClone:(id)sender
{
    [self willChangeValueForKey:@"cloneWindowVisible"];
    //[self.cloneWindowController setIncremental:NO];
    [self.cloneWindowController showIncremental];
    [self didChangeValueForKey:@"cloneWindowVisible"];
}

- (void)cloneWindowWillClose
{
    
}

- (BOOL)cloneWindowVisible
{
    if (_cloneWindowController == nil) return NO;
    
    return [self.cloneWindowController.window isVisible];
}

- (void)dealloc
{
    [_cloneWindowController release], _cloneWindowController = nil;
    [super dealloc];
}

@end