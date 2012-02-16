/*
 *  CVMainController.h
 *  CloneVolume
 *
 *  Created by Pumptheory P/L on 12/01/11.
 *  Copyright 2011 Pumptheory P/L. All rights reserved.
 *
 */

#include "CVDisk.h"

@protocol CVMainControllerDelegate;

@interface CVMainController : NSObject {
  DASessionRef diskArbSession;
  NSMutableArray *sourceDisks;
  NSMutableArray *targetDisks;
  // Array rather than set to preserve order
  NSMutableArray *allDisks;
  FILE *pipe;
  BOOL busy;
  BOOL aborted;
  NSSize origWindowSize;
  BOOL rebuildPending;
  BOOL incremental;
  
  CVDisk *chosenTargetDisk;
  NSSize progressWindowSize;
  id<CVMainControllerDelegate> delegate;

  IBOutlet NSWindow *mainWindow;
  IBOutlet NSCollectionView *sourceCollectionView;
  IBOutlet NSCollectionView *targetCollectionView;
  IBOutlet NSTabView *tabView;
  IBOutlet NSProgressIndicator *progressIndicator;
  IBOutlet NSTextField *progressTitle;
  IBOutlet NSTextField *progressStatus;
  IBOutlet NSImageView *cautionImageView;
  IBOutlet NSTextField *targetProblemTextField;
  IBOutlet NSButton *cloneButton;
  IBOutlet NSButton *incrementalCheckBox;
}

@property (retain) NSMutableArray *sourceDisks;
@property (retain) NSMutableArray *targetDisks;
@property (readonly) NSCollectionView *sourceCollectionView;
@property (readonly) NSCollectionView *targetCollectionView;
@property (assign) BOOL aborted;
@property (assign) BOOL incremental;
@property (assign) BOOL busy;

@property (retain) CVDisk *chosenTargetDisk;
@property (assign) NSSize progressWindowSize;
@property (assign) id<CVMainControllerDelegate> delegate;

- (IBAction)next:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)clone:(id)sender;
- (IBAction)abort:(id)sender;

@end

@protocol CVMainControllerDelegate <NSObject>

- (void)windowWillResizeToProgressRect:(NSRect)rect;
- (void)windowWillResizeToMainRect:(NSRect)rect;
- (void)windowDidResizeToMainRect:(NSRect)rect;

- (void)cloneDidFinishSuccessfully;

@end
