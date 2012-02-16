//
//  ADDExclusionsViewController.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MGAViewController.h"
#import "ADDExclusionsModel.h"
#import <AppKit/AppKit.h>

@protocol ADDExclusionsVCDelegate;

@interface ADDExclusionsVC : MGAViewController
{
    IBOutlet NSOutlineView *outlineView;
    IBOutlet NSTableColumn *labelColumn;
    id <ADDExclusionsVCDelegate> delegate;
    BOOL didSave;
    ADDExclusionsModel *model;
    BOOL excludeRootDirs;
    NSTask *_exclusionsHelper;
    IBOutlet NSTextField *loadingString;
}

@property (assign) id <ADDExclusionsVCDelegate> delegate;
@property (retain) ADDExclusionsModel *model;
@property (assign) BOOL excludeRootDirs;
@property (retain) NSTask *_exclusionsHelperTask;

- (void)showOutline;
- (void)reloadDataOnMainThread;

- (IBAction)cancel:(id)sender;
- (IBAction)save:(id)sender;

- (void)releaseExclusionsHelper;

@end

@protocol ADDExclusionsVCDelegate

- (void)exclusionsDidSave;
- (void)exclusionsDidCancel;

@end

