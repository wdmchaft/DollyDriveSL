//
//  DollyDriveAppAppDelegate.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "DollyDriveAppAppDelegate.h"

#import "ADDLogReporter.h"
#import "Sparkle/SUUpdater.h"

#import "ADDInfoView.h"
#import "ADDExclusionsVC.h"
#import "ADDLaunchDManagement.h"


@interface DollyDriveAppAppDelegate (Private)

- (void)okToQuit:(NSNotification *)notif;
- (void)notOkToQuit:(NSNotification *)notif;

@end

@implementation DollyDriveAppAppDelegate

@synthesize windowController;
@synthesize feedbackWindowController;
@synthesize prefsWindowController;
@synthesize appConfig;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // create Application Support/DollyDrive if needed
    
    // -rwx------
    NSDictionary *dirAttribs = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt:0700], NSFilePosixPermissions,
                                nil];
    //NSDictionary *dirAttribsAdmin = [NSDictionary dictionaryWithObjectsAndKeys:
      //                          [NSNumber numberWithInt:0455], NSFilePosixPermissions,
        //                        nil];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error = NULL;
    
    appConfig = [ADDAppConfig sharedAppConfig];
    [appConfig isFirstRun]; // make sure we check for config file existance before they are created
    
    [fileManager createDirectoryAtPath:appConfig.supportDirectory withIntermediateDirectories:YES attributes:dirAttribs error:NULL];
    //if(![fileManager createDirectoryAtPath:appConfig.cloneSupportDirectory withIntermediateDirectories:YES attributes:dirAttribsAdmin error:&error])
      //   NSLog(@"Error: Create folder failed for %@ - error:%@", appConfig.cloneSupportDirectory, error);
    
    [ADDServerConfig createThrottleConfigIfNeeded];
    
    if (![appConfig runCloneHelper])
    {
        printf("Could not copy clone helper: %s", [[appConfig.error localizedDescription] UTF8String]);
        //[pool drain];
        exit(1006);
    }
    
    //ADDLaunchDManagement *launchDMgmt = [[[ADDLaunchDManagement alloc] init] autorelease];
    //[launchDMgmt createOrReplaceSchedulerLaunchDaemon];
    

    self.windowController = [[[ADDMainWindowController alloc] init] autorelease];
    [self.windowController showWindow:self];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [self.windowController showWindow:self];
    return YES;
}

// we need to be able to allow the embedded pref pane to shutdown cleanly
- (void) setTMPrefPaneObject:(TMPreferencePane *)theTMPrefPaneObject
{
    // we're not 
    tmPrefPaneObject = theTMPrefPaneObject;
    
    if (theTMPrefPaneObject)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(okToQuit:) name:NSPreferencePaneDoUnselectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notOkToQuit:) name:NSPreferencePaneCancelUnselectNotification object:nil];
    }
    else 
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSPreferencePaneDoUnselectNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSPreferencePaneCancelUnselectNotification object:nil];
    }
}

- (void)notOkToQuit:(NSNotification *)notif
{
    attemptingToQuit = NO;
    
    // seems the TM pref pane is in the middle of something...
}

- (void)okToQuit:(NSNotification *)notif
{
    // exit was previously delayed by the Time Machine pref pane responding NSTerminateCancel
    [self setTMPrefPaneObject:nil];
    if (attemptingToQuit)
        [[NSApplication sharedApplication] terminate:self];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    attemptingToQuit = YES;
    return tmPrefPaneObject && [tmPrefPaneObject shouldUnselect] == NSUnselectLater ? NSTerminateCancel : NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [windowController.window performClose:self];

    [windowController release];
    
    // nasty hack since I can't figure out where the retain cycles or over-retaining of all the windows
    // is happening...
    [(ADDExclusionsVC *)((ADDInfoView *)(windowController.viewController.windowController.viewController)).exclusionsWindowController.viewController releaseExclusionsHelper];
}

#pragma mark IBActions

- (IBAction)sendFeedback:(id)sender
{
    if (!self.feedbackWindowController)
        self.feedbackWindowController = [[[ADDFeedbackWindowController alloc] init] autorelease];
    
    [self.feedbackWindowController showWindow:sender];
}

- (IBAction)showPrefs:(id)sender
{
    if (!self.prefsWindowController)
        self.prefsWindowController = [[[ADDPrefsWindowController alloc] init] autorelease];
    
    [self.prefsWindowController showWindow:sender];
}

- (IBAction)crash:(id)sender
{
    //*(long*)0 = 0xDEADBEEF;
}

- (IBAction)support:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://support.dollydrive.com"]];
}

- (IBAction)showMainWindow:(id)sender
{
    [self.windowController showWindow:self];
}

#pragma mark -
#pragma mark Sparkle Delegate

// This method allows you to add extra parameters to the appcast URL,
// potentially based on whether or not Sparkle will also be sending along
// the system profile. This method should return an array of dictionaries
// with keys: "key", "value", "displayKey", "displayValue", the latter two
// being human-readable variants of the former two.
- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater
                 sendingSystemProfile:(BOOL)sendingProfile
{
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:1];
    
    if ([ADDServerConfig configFileExists])
    {
        ADDServerConfig *config = [[[ADDServerConfig alloc] initFromFile] autorelease];
        NSDictionary *userDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  config.afpUsername, @"value",
                                  config.afpUsername, @"displayValue",
                                  @"username", @"key",
                                  @"Dolly Drive Username", @"displayKey",
                                  nil];
        
        [ret addObject:userDict];
    }
    
    return ret;
}

@end
