//
//  ADDCloneWindowController.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 4/04/11.
//  Copyright 2011 Pumptheory Pty Ltd. All rights reserved.
//

#import "CVMainController.h"

@protocol ADDCloneWindowDelegate;
@class ADDColouredView;

@interface ADDCloneWindowController : NSWindowController <CVMainControllerDelegate>
{
    id <ADDCloneWindowDelegate> _delegate;
    CVMainController*           _cloneController;
    ADDColouredView*            _colouredView;
    NSRect                      _origControllerFrame;
    NSSize                      _origWindowSize;
    NSView*                     _cloneControllerView;
}

@property (assign) id <ADDCloneWindowDelegate>  delegate;
@property (retain) IBOutlet CVMainController*   cloneController;
@property (retain) IBOutlet ADDColouredView*    colouredView;
@property (retain) IBOutlet NSView*             cloneControllerView;

- (void)showIncremental;
- (void)showNewClone;

@end

@protocol ADDCloneWindowDelegate

- (void)cloneWindowWillClose;

@end