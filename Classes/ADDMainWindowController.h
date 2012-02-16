//
//  ADDWindowController.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MGAWindowController.h"

typedef enum {
    ADDViewControllerAskUserDetails,
    ADDViewControllerInfoView,
    ADDViewControllerActions
} ADDViewController;

@interface ADDMainWindowController : MGAWindowController
{
    IBOutlet NSImageView *mainLogo;
}

- (void)changeViewController:(ADDViewController)vcId;

@end
