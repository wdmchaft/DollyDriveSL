//
//  DollyDriveAppAppDelegate.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDMainWindowController.h"
#import "ADDFeedbackWindowController.h"
#import "ADDAppConfig.h"
#import "ADDPrefsWindowController.h"

#import "TMPreferencePane.h"

#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5)
@interface DollyDriveAppAppDelegate : NSObject
#else
@interface DollyDriveAppAppDelegate : NSObject <NSApplicationDelegate>
#endif
{
    ADDMainWindowController *windowController;
    TMPreferencePane *tmPrefPaneObject;
    BOOL attemptingToQuit;
    ADDAppConfig *appConfig;
    
    ADDFeedbackWindowController *feedbackWindowController;
    ADDPrefsWindowController *prefsWindowController;
}

@property (retain) ADDMainWindowController *windowController;
@property (retain) ADDFeedbackWindowController *feedbackWindowController;
@property (retain) ADDPrefsWindowController *prefsWindowController;
@property (readonly) ADDAppConfig *appConfig;

- (void) setTMPrefPaneObject:(TMPreferencePane *)theTMPrefPaneObject;

- (IBAction)sendFeedback:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (IBAction)crash:(id)sender;
- (IBAction)support:(id)sender;
- (IBAction)showMainWindow:(id)sender;

@end
