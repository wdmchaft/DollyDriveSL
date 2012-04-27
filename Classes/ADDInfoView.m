//
//  ADDInfoView.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 13/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDInfoView.h"

#import "DollyDriveAppAppDelegate.h"
#import "ADDBonjour.h"
#import "ADDAppConfig.h"
#import "ADDServerConfig.h"
#import "ADDKeyChainManagement.h"

#import "TMSliderView.h"
#import "AppleTMSettings.h"

#import "NSStringAdditions.h"

#import "MGANSImage+IconServices.h"

#import "NDAlias.h"
#import "TMSliderControl.h"
#import "NSButtonAdditions.h"
#import "CVDisk.h"
#import "ADDKeyManagement.h"
#import "ADDLaunchDManagement.h"
#include "ADDScheduleConfig.h"
#include "DSCloneTask.h"

@interface ADDInfoView (Private)

- (id)updateTMName;
- (id)updateTMOldestBackup;
- (id)updateTMLatestBackup;
- (id)updateTMNextBackup;
- (id)updateTMOnOff;
- (id)updateProgressTextField;
- (id)updateProgressIndicator;

- (void)presentChangeVolumeView;
- (void)presentSizeView;

- (void)setProgress:(NSNumber *)progressNSNumber;
- (void)setTMVolumeWithVolumeRefNSNum:(NSNumber *)volRefNSNum;
- (void)unmountTMVolumeWithVolumeRefNSNum:(NSNumber *)volRefNSNum;
- (void)finishSettingVolumeWithErrorString:(NSString *)errorString;
- (void)finishSettingVolumeWithErrorString2:(NSString *)errorString;

@end

void *ADDTMPrefPaneNameFieldObserver = (void *)@"ADDTMPrefPaneNameFieldObserver";
void *ADDTMPrefPaneOldestBackupFieldObserver = (void *)@"ADDTMPrefPaneOldestBackupFieldObserver";
void *ADDTMPrefPaneLatestBackupFieldObserver = (void *)@"ADDTMPrefPaneLatestBackupFieldObserver";
void *ADDTMPrefPaneNextBackupFieldObserver = (void *)@"ADDTMPrefPaneNextBackupFieldObserver";
void *ADDTMPrefPaneProgressTextFieldObserver = (void *)@"ADDTMPrefPaneProgressTextFieldObserver";
void *ADDTMPrefPaneProgressIndicatorObserver = (void *)@"ADDTMPrefPaneProgressIndicatorObserver";


@implementation ADDInfoView

@synthesize volumeName;
@synthesize oldestBackup;
@synthesize nextBackup;
@synthesize latestBackup;
@synthesize exclusionsWindowController;
@synthesize mainWindowCloneVC;
@synthesize progressDescription;
@synthesize progressIndicatorMaxValue;
@synthesize progressIndicatorMinValue;
@synthesize progressIndicatorDoubleValue;
@synthesize progressIndicatorIsIndeterminate;
@synthesize shareSizeString;
@synthesize availableSizeString=_availableSizeString;
@synthesize usedSizeString=_usedSizeString;
@synthesize progressTimer;
@synthesize alertIconImage;
@synthesize dollyConfigured;
@synthesize username;
@synthesize hoursLabel, scheduleOn, throttleOn, dailyOffStartTime, dailyOffEndTime, lastBackupLabel, nextCloneLabel, dollyUsage, dailyBackupTime, cloneProgress, cloneInProgress;
@synthesize bandwidthThrottle;

const NSString *ADDSchedulerOnNotification = @"dollyclonescheduler.on";
const NSString *ADDSchedulerOffNotification = @"dollyclonescheduler.off";
const NSString *ADDSchedulerStartNotification = @"dollyclonescheduler.start";
const NSString *ADDSchedulerStopNotification = @"dollyclonescheduler.stop";
const NSString *ADDSchedulerProgressNotification = @"dollyclonescheduler.progress";

void DollyNotificationCenterCallBack(CFNotificationCenterRef center,
                                  void *observer,
                                  id name,
                                  const void *object,
                                  CFDictionaryRef userInfo)
{
    //NSLog(@"clone notification %@", name);
    
   // DSCloneTask *task = (DSCloneTask *)object;
    if ([name isEqual:ADDSchedulerProgressNotification] )
    {
      //DSCloneTask *task = (DSCloneTask *)CFDictionaryGetValue(userInfo, CFSTR("task"));
      [(id)observer updateCloneProgress];
    }
    if ([name isEqual:ADDSchedulerStartNotification])
    {
        [(id)observer showCloneProgressBar];
    }
    if ([name isEqual:ADDSchedulerStopNotification])
    {
        [(id)observer hideCloneProgressBar];
    }
}
 

//- (void)callbackWithNotification:(NSNotification *)myNotification {
   // [[NSSound soundNamed:@"pop"] play]; // yet it worked
//}



/*
- (void) allDistributedNotifications:(NSNotification *)note {
    
    NSString *object = [note object];
    NSString *name = [note name];
    NSDictionary *userInfo = [note userInfo];
    NSLog(@"<%p>%s: object: %@ name: %@ userInfo: %@", self, __PRETTY_FUNCTION__, object, name, userInfo);
}
        */

- (void)awakeFromNib
{

    /*
    NSDistributedNotificationCenter *center = 
    [NSDistributedNotificationCenter defaultCenter]; 
    [center addObserver: self 
               selector: @selector(callbackWithNotification:) 
                   name: @"dollyclonescheduler.start" 
                 object: nil]; 
 
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(allDistributedNotifications:)
                                                            name:nil
                                                          object:nil];
       */
     [self setTitle:@"Dolly Drive"];
  
    self.alertIconImage = [NSImage mga_imageWithIconServicesConstant:kAlertNoteIcon];
    
    [backupProgressIndicator setUsesThreadedAnimation:YES];
    
    //TODO: move this TM stuff out to a separate class
    
    NSBundle *prefBundle = [NSBundle bundleWithPath:@"/System/Library/PreferencePanes/TimeMachine.prefPane"];
    
    if (!prefBundle)
    {
        NSLog(@"couldn't load TimeMachine pref pane bundle");

        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Loading Time Machine preferences failed"];
        [alert setInformativeText:@"Unable to load the Time Machine preferences"];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
    }
    
    Class prefPaneClass = [prefBundle principalClass];
    
    // backup time machine config if first run
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    if ([appConfig isFirstRun])
        [appConfig backupOrigTimeMachinePlist];
    
    self.username = appConfig.serverConfig.afpUsername;
    
    self.shareSizeString = [NSString humanReadableFileSize:[[[[ADDAppConfig sharedAppConfig] serverConfig] quotaSize] doubleValue]*1024*1024*1024 usingBaseTenUnits:YES];
        
    self.availableSizeString = [[NSUserDefaults standardUserDefaults] valueForKey:@"cachedAvailableSize"];
    self.usedSizeString = [[NSUserDefaults standardUserDefaults] valueForKey:@"cachedUsedSize"];
    tmPrefPaneObject = [[prefPaneClass alloc] initWithBundle:prefBundle];
    
    
    [dollyMaxValue setStringValue:[NSString humanReadableFileSize:[[[[ADDAppConfig sharedAppConfig] serverConfig] quotaSize] doubleValue]*1024*1024*1024 usingBaseTenUnits:YES]];               
    [dollyMiddleValue setStringValue:[NSString humanReadableFileSize:([[[[ADDAppConfig sharedAppConfig] serverConfig] quotaSize] doubleValue]*1024*1024*1024/2) usingBaseTenUnits:YES]];  
    
    //dollyUsage = [[NSLevelIndicator alloc] init];
    [dollyUsage setMaxValue:[[[[ADDAppConfig sharedAppConfig] serverConfig] quotaSize] doubleValue]*1024*1024*1024];
    [dollyUsage setDoubleValue:[self.usedSizeString doubleValue]];
    
    
    // need to set the pref pane object on the app delegate so it can quit cleanly
    DollyDriveAppAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate setTMPrefPaneObject:tmPrefPaneObject];
    
    if ([tmPrefPaneObject loadMainView])
    {
        [tmPrefPaneObject willSelect];
        tmPrefPaneView = [tmPrefPaneObject mainView];
        
        // add view outside view
        NSRect frame = [tmPrefPaneView frame];
        //frame.origin.y = -1 - frame.size.height;
        [tmPrefPaneView setFrame:frame];
        
        [prefPaneHostView addSubview:tmPrefPaneView];
        
        [tmPrefPaneObject didSelect];
        
        // sync TM pref pane info
        [[self updateTMName] addObserver:self forKeyPath:@"stringValue" options:0 context:ADDTMPrefPaneNameFieldObserver];
        [[self updateTMOldestBackup] addObserver:self forKeyPath:@"stringValue" options:0 context:ADDTMPrefPaneOldestBackupFieldObserver];
        [[self updateTMLatestBackup] addObserver:self forKeyPath:@"stringValue" options:0 context:ADDTMPrefPaneLatestBackupFieldObserver];
        [[self updateTMNextBackup] addObserver:self forKeyPath:@"stringValue" options:0 context:ADDTMPrefPaneNextBackupFieldObserver];
        [[self updateProgressTextField] addObserver:self forKeyPath:@"stringValue" options:0 context:ADDTMPrefPaneProgressTextFieldObserver];
        id TMprogressIndicator = [self updateProgressIndicator];
        [TMprogressIndicator addObserver:self forKeyPath:@"isIndeterminate" options:0 context:ADDTMPrefPaneProgressIndicatorObserver];
        [TMprogressIndicator addObserver:self forKeyPath:@"doubleValue" options:0 context:ADDTMPrefPaneProgressIndicatorObserver];
        
        // dollyUsage = [[NSLevelIndicator alloc] init];
        
        [dollyUsage setMaxValue:[[[[ADDAppConfig sharedAppConfig] serverConfig] quotaSize] doubleValue]*1024*1024*1024];
        [dollyUsage setDoubleValue:[self.usedSizeString doubleValue]];
                    
    }
    else 
    {
        NSLog(@"couldn't loadMainView");

        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Displaying Time Machine preferences failed"];
        [alert setInformativeText:@"Unable to display the Time Machine preferences"];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
    }
    
    NSColor* buttonColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
    
    [ddOnButton setTextColor:buttonColor];
    [ddOffButton setTextColor:buttonColor];
    [dailyBackupTime setEnabled:YES]; //(tag == 0)];
    
    [self loadSettings];
    [self showLastBackup];
    [applyButton setEnabled:NO];
    
    /*
    /* Create a notification center */
    /* Tell notifyd to alert us when this notification
     is received. */
    //CFNotificationCenterGetDistributedCenter   CFNotificationCenterGetDarwinNotifyCenter
    
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    

    if (center) {
    
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.progress"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);   
        
        
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.start"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);   
        
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.stop"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);   
        
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.stop"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately); 
    }

}



- (void) showCloneProgressBar
{
    [addCloneProgress setHidden:NO];
    [addCloneProgress setIndeterminate:YES];
    [addCloneProgress startAnimation:self];
    [cloneStatusLabel setStringValue:@"Cloning"];
}
- (void) hideCloneProgressBar
{
    [addCloneProgress setHidden:YES];
    [addCloneProgress setIndeterminate:NO];
    [addCloneProgress stopAnimation:self];
    [cloneStatusLabel setStringValue:@"Done"];
    cloneInProgress = NO;
    [self showLastBackup];
}

- (void) updateCloneProgress  //:(DSCloneTask*)task
{
    cloneInProgress = YES;
    [self showCloneProgressBar];
    //[cloneProgress setDoubleValue:task.progress];
}



    
- (void)presentChangeVolumeView
{
    [scheduleConfigBox setHidden:YES];
    [addDollyBox setHidden:NO];
   // [(ADDMainWindowController *)self.windowController resizeToViewHeight:[self.view frame].size.height + [changeVolumeView frame].size.height
     //                                                         fromHeight:[self.view frame].size.height
       //                                                          animate:YES];
    
    //[[self.view superview] addSubview:changeVolumeView];
      //  
    //[self.windowController.window makeFirstResponder:addDollyNowButton];
   // [self.windowController.window setDefaultButtonCell:[addDollyNowButton cell]];
}

- (void)turnTMOff
{
    NSButton *button = [tmPrefPaneObject valueForKey:@"_offButton"];
    [[button target] performSelector:[button action] withObject:button];
}

- (void)turnTMOn
{
    NSButton *button = [tmPrefPaneObject valueForKey:@"_onButton"];
    [[button target] performSelector:[button action] withObject:button];
}

- (void)presentSizeView
{


    // [NSApp beginSheet:addDollySheet modalForWindow:self.windowController.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];

    // also adding the clone view
    //if (!self.mainWindowCloneVC)
    //    self.mainWindowCloneVC = [[[ADDMainWindowCloneVC alloc] initWithNibName:nil bundle:nil] autorelease];
    
    /*
    [(ADDMainWindowController *)self.windowController resizeToViewHeight:[self.view frame].size.height //+
                                                                        // [sizeView frame].size.height +
                                                                        // [mainWindowCloneVC.view frame].size.height
                                                          fromHeight:[self.view frame].size.height
                                                                 animate:YES];
    // want sizeView above the clone view
    NSRect sizeViewFrame = [sizeView frame];
    sizeViewFrame.origin.y = [mainWindowCloneVC.view frame].size.height;
    [sizeView setFrame:sizeViewFrame];
    
    [[self.view superview] addSubview:sizeView];
    //[[self.view superview] addSubview:self.mainWindowCloneVC.view];
     */
    
    // if first run, stop backups and show assistant
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    if ([appConfig isFirstRun])
    {
        [self turnTMOff];
        //[self showAssistant:nil];
    }
    
    self.dollyConfigured = YES;
}

#pragma mark -
#pragma mark Keeping fields in sync

//TODO: Critical: the below valueForKey: calls should trap for exceptions

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == ADDTMPrefPaneNameFieldObserver)
        [self updateTMName];
    else if (context == ADDTMPrefPaneOldestBackupFieldObserver)
        [self updateTMOldestBackup];
    else if (context == ADDTMPrefPaneLatestBackupFieldObserver)
        [self updateTMLatestBackup];
    else if (context == ADDTMPrefPaneNextBackupFieldObserver)
        [self updateTMNextBackup];
    else if (context == ADDTMPrefPaneProgressTextFieldObserver)
        [self updateProgressTextField];
    else if (context == ADDTMPrefPaneProgressIndicatorObserver)
        [self updateProgressIndicator];
}

- (void)updateProgress
{
    NSProgressIndicator *tmProgressIndicator = [tmPrefPaneObject valueForKey:@"_progressIndicator"];
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    NSTextField *tmProgressTextField = [tmPrefPaneObject valueForKey:@"_progressTextField"];
    
    self.progressDescription = [tmProgressTextField stringValue];
    
    self.progressIndicatorIsIndeterminate = [tmProgressIndicator isIndeterminate];
    self.progressIndicatorMinValue = [tmProgressIndicator minValue];
    self.progressIndicatorMaxValue = [tmProgressIndicator maxValue];
    self.progressIndicatorDoubleValue = [tmProgressIndicator doubleValue];    

    if ([tmProgressIndicator isHidden] && ![self.progressDescription hasPrefix:@"Making backup disk available"])
    {
        if (appConfig.backupInProgress == YES)
            appConfig.backupInProgress = NO;
        /*
        [nextBackupLabelTextField setStringValue:@"Next Backup:"];
        [nextBackupTextField setHidden:NO];
        [backupProgressTextField setHidden:YES];
        [backupProgressIndicator setHidden:YES];
        
        [backupProgressIndicator stopAnimation:self];
        
        [self.progressTimer invalidate];
        self.progressTimer = nil;
         */
    }
    else 
    {
        if (appConfig.backupInProgress == NO)
            appConfig.backupInProgress = YES;
        /*
        [nextBackupLabelTextField setStringValue:@"Backing Up:"];
        [nextBackupTextField setHidden:YES];
        [backupProgressTextField setHidden:NO];
        [backupProgressIndicator setHidden:NO];
        
        [backupProgressIndicator startAnimation:self];
        */
        
        NSString* mountPoint = [NSString stringWithFormat:@"/Volumes/%@", [ADDAppConfig sharedAppConfig].serverConfig.afpVolumeName];
        BOOL isDir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:mountPoint isDirectory:&isDir];
        if (!exists && !isDir)
        {
            mountPoint = @"/Volumes/Dolly Drive";
        }
              
        NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:mountPoint error:NULL];
        NSDictionary* rootFileSystemAttributes  = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/" error:NULL];
        
        //CVDisk* dollyDriveDisk = [CVDisk diskWithMountPath:@"/Volumes/Dolly Drive"];
        
        //NSLog(@"spaceUsed %@", [NSString humanReadableFileSize:[dollyDriveDisk spaceUsed] usingBaseTenUnits:YES]);
        //NSLog(@"mediaSize: %@", [NSString humanReadableFileSize:[dollyDriveDisk mediaSize] usingBaseTenUnits:YES]);
        
        if (fileAttributes != nil && rootFileSystemAttributes != nil)
        {
            NSNumber* fileSystemNumber = [fileAttributes objectForKey:NSFileSystemNumber];
            NSNumber* rootFileSystemNumber = [rootFileSystemAttributes objectForKey:NSFileSystemNumber];
            
            if (![fileSystemNumber isEqualToNumber:rootFileSystemNumber])
            {
            
                unsigned long long availableSize = [[fileAttributes objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
                 //   [dollyMaxValue setStringValue:[NSString humanReadableFileSize:[[[[ADDAppConfig sharedAppConfig] serverConfig] quotaSize] doubleValue]*1024*1024*1024 usingBaseTenUnits:YES]];  
                unsigned long long totalSize = [[[[ADDAppConfig sharedAppConfig] serverConfig] quotaSize] doubleValue]*1024*1024*1024;//[[fileAttributes objectForKey:NSFileSystemSize] unsignedLongLongValue];


                unsigned long long usedSize = totalSize - availableSize;
                //double usedSpace = usedSize;
                
                self.availableSizeString = [NSString stringWithFormat:@"%@ Used, %@ Available", 
                                            [NSString humanReadableFileSize:usedSize usingBaseTenUnits:YES],
                                            [NSString humanReadableFileSize:availableSize usingBaseTenUnits:YES]];
                
                self.usedSizeString = [NSString stringWithFormat:@"%llu", usedSize];
                                            //[NSString humanReadableFileSize:usedSize usingBaseTenUnits:NO]];
                
                
                //[dollyUsage setMaxValue:totalSize];
                [dollyUsage setDoubleValue:usedSize];
                [dollyUsage setNeedsDisplay:YES];
                //NSLog(@"used = %ul, total = %ul, avail = %ul", usedSize, totalSize, availableSize);
                [[NSUserDefaults standardUserDefaults] setValue:self.availableSizeString forKey:@"cachedAvailableSize"];
                [[NSUserDefaults standardUserDefaults] setValue:self.usedSizeString forKey:@"cachedUsedSize"];
            }
            else
            {
                self.availableSizeString = [[NSUserDefaults standardUserDefaults] valueForKey:@"cachedAvailableSize"];
                self.usedSizeString = [[NSUserDefaults standardUserDefaults] valueForKey:@"cachedUsedSize"];
            }
        }
        else
        {
            self.availableSizeString = [[NSUserDefaults standardUserDefaults] valueForKey:@"cachedAvailableSize"];
            self.usedSizeString = [[NSUserDefaults standardUserDefaults] valueForKey:@"cachedUsedSize"];
        }
        
        if (!self.progressTimer)
            self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    }
    
    /*
    self.progressIndicatorIsIndeterminate = [tmProgressIndicator isIndeterminate];
    
    //TODO: not locale safe
    if ([self.progressDescription hasPrefix:@"Stopping backup"] || [self.progressDescription hasPrefix:@"Cleaning up"])
        self.progressIndicatorIsIndeterminate = YES;
    
    // indeterminate status doesn't seem to be set correctly to start with
    if (self.progressIndicatorDoubleValue <= self.progressIndicatorMinValue)
        self.progressIndicatorIsIndeterminate = YES;    
     */
}

- (id)updateProgressTextField
{
    NSTextField *tmProgressTextField = [tmPrefPaneObject valueForKey:@"_progressTextField"];

    [self updateProgress];
        
    return tmProgressTextField;
}

- (id)updateProgressIndicator
{
    NSProgressIndicator *tmProgressIndicator = [tmPrefPaneObject valueForKey:@"_progressIndicator"];
        
    [self updateProgress];
    
    return tmProgressIndicator;
}

- (id)updateTMName
{
    NSTextField *tmNameField = [tmPrefPaneObject valueForKey:@"_destinationNameTextField"];
    self.volumeName = [tmNameField stringValue];
    
    
    if ([self.volumeName isEqualToString:[ADDAppConfig sharedAppConfig].serverConfig.afpVolumeName])
    {
        if ([mountHelpView superview])
            [mountHelpView removeFromSuperview];
            
        [scheduleConfigBox setHidden:NO];
        [addDollyBox setHidden:YES];
        
        self.dollyConfigured = YES;
        
        //if ([changeVolumeView superview])
          //  [changeVolumeView removeFromSuperview];
        //if (willPresentChangeView)
        //{
            // this is a hacky workaround to the fact that under lion sometimes
            // we end up with multiple views displayed since the name is set to nil briefly
            // before it set to the actual name
            // TODO: better solution please!
        //    [scheduleConfigBox setHidden:NO];
        //    [addDollyBox setHidden:YES];
            
        //    willPresentChangeView = NO;
           
            //[changeVolumeView performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:0.5];
       // }
        
        //if (![sizeView superview])
       // {
        //    [self performSelector:@selector(presentSizeView) withObject:nil afterDelay:0.0];
        //}
    }
    else
    {
        // if the volume name doesn't match, choose the drive
        //TODO: Critical: also check server is ADDAFPForwardingHost (or ADDAFPForwardingHost:ADDAFPForwardingPort?)
        //willPresentChangeView = YES;
        //[self performSelector:@selector(presentChangeVolumeView) withObject:nil afterDelay:0];
        [scheduleConfigBox setHidden:YES];
        [addDollyBox setHidden:NO];
    }
    
    return tmNameField;
}

- (id)updateTMOldestBackup
{
    NSTextField *tmOldestBackupField = [tmPrefPaneObject valueForKey:@"_oldestBackupTextField"];
    self.oldestBackup = [tmOldestBackupField stringValue];
    
    return tmOldestBackupField;
}

- (id)updateTMLatestBackup
{
    NSTextField *tmLatestBackupField = [tmPrefPaneObject valueForKey:@"_latestBackupTextField"];
    self.latestBackup = [tmLatestBackupField stringValue];
    
    return tmLatestBackupField;
}

- (id)updateTMNextBackup
{
    NSTextField *tmNextBackupField = [tmPrefPaneObject valueForKey:@"_nextBackupTextField"];
    self.nextBackup = [tmNextBackupField stringValue];
    
    // the next field is updated along with the on/off button
    [self updateTMOnOff];
    
    return tmNextBackupField;
}

- (BOOL)TMisOn
{
    TMSliderView *tmOnOffView = [tmPrefPaneObject valueForKey:@"_onOffSliderView"];
    return (NSInteger)[tmOnOffView state] == 1;
}

- (id)updateTMOnOff
{
    TMSliderView *tmOnOffView = [tmPrefPaneObject valueForKey:@"_onOffSliderView"];
    [onOffSlider setStateNoAction:[tmOnOffView state]];
    
    NSColor* buttonColor = [tmOnOffView state] ? [NSColor colorWithCalibratedRed:0.28627 green:0.53725 blue:0.54510 alpha:1.] : [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
    
    [ddOnButton setTextColor:buttonColor];

    return nil;
}

- (void)setProgress:(NSNumber *)progressNSNumber
{
    [addDollyProgress setDoubleValue:[progressNSNumber doubleValue]];
}

-(IBAction)tmSliderChanged:(id)sender
{    
    NSButton *button = ![onOffSlider state] ? [tmPrefPaneObject valueForKey:@"_offButton"] : [tmPrefPaneObject valueForKey:@"_onButton"];
    [[button target] performSelector:[button action] withObject:button];
    [tmPrefPaneView setNeedsLayout:YES];
    [tmPrefPaneView viewWillDraw];
}

- (IBAction)turnBackupsOn:(id)sender
{
    NSButton *button = [tmPrefPaneObject valueForKey:@"_onButton"];
    [[button target] performSelector:[button action] withObject:button];
}

- (IBAction)turnBackupsOff:(id)sender
{
    NSButton *button = [tmPrefPaneObject valueForKey:@"_offButton"];
    [[button target] performSelector:[button action] withObject:button];
}

- (void) restoreTMConfigAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[NSApplication sharedApplication] terminate:nil];
}

- (IBAction)restoreTMPlist:(id)sender
{
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    
    if (![appConfig timeMachinePlistBackupExists])
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"com.apple.TimeMachine.plist backup not found"];
        [alert setInformativeText:@"Sorry - we couldn't find the main configuration backup. Please check the Dolly Drive support web pages for information on resolving this."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
        return;
    }
    
    //TODO: move this stuff to AppConfig
    
    NSString *origBackupPath = [appConfig mainTimeMachinePlistBackupPath];
    NSString *dollyDriveConfigBackupPath = [appConfig dollyDriveTimeMachinePlistBackupPath];
    NSString *systemPlist = @"/Library/Preferences/com.apple.TimeMachine.plist";
    
    NSError *anError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:dollyDriveConfigBackupPath])
        [fm removeItemAtPath:dollyDriveConfigBackupPath error:&anError];
    
    if (!anError)
        [fm moveItemAtPath:systemPlist toPath:dollyDriveConfigBackupPath error:&anError];
    
    if (!anError)
        [fm copyItemAtPath:origBackupPath toPath:systemPlist error:&anError];
    
    if (anError)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"com.apple.TimeMachine.plist could not be replaced"];
        [alert setInformativeText:[NSString stringWithFormat:@"There was a problem replacing the configuration file. Please check the Dolly Drive support web pages for information on resolving this. (%@)", [anError localizedDescription]]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
        return;
        
    }
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Configuration successfully replaced"];
    [alert setInformativeText:@"Dolly Drive will now exit."];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                      modalDelegate:self
                     didEndSelector:@selector(restoreTMConfigAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
    
    
}

- (IBAction)accountDetails:(id)sender
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://10.0.4.9:30001/auth/users/login"]
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:60.0];
    [ [ NSWorkspace sharedWorkspace ] openURL:[request URL] ];
}

- (void) changeUserAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[NSApplication sharedApplication] terminate:nil];
}


- (IBAction)changeUser:(id)sender
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *anError = nil;
    
    [fm removeItemAtPath:[ADDServerConfig filePath] error:&anError];
    
    if (!anError)
    {
        ADDKeyManagement *km = [[[ADDKeyManagement alloc] init] autorelease];
        [fm removeItemAtPath:[km privateKeyFilePath] error:&anError];
        
        if (!anError)
            [fm removeItemAtPath:[km publicKeyFilePath] error:&anError];
    }
    
    if (anError)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Unable to remove all user settings"];
        [alert setInformativeText:@"You may wish to try removing the directory ~/Library/Application Settings/DollyDrive yourself or consult the Dolly Drive support web pages for more information."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
        return;
    }
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"User settings removed"];
    [alert setInformativeText:@"Dolly Drive will now exit. Next time you start Dolly Drive you will be able to login with any Dolly Drive User"];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                      modalDelegate:self
                     didEndSelector:@selector(restoreTMConfigAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
}

- (void)mountTMVolume
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    ADDAppConfig *config = [ADDAppConfig sharedAppConfig];

    FSVolumeRefNum volRefNum = 0;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"afp://%@:%d/%@", ADDAFPForwardingHost, ADDAFPForwardingPort, config.serverConfig.afpVolumeName]];
    
    NSString *password = config.serverConfig.afpPassword;
    OSStatus ret = FSMountServerVolumeSync (
                                            (CFURLRef)url, //CFURLRef url,
                                            NULL, //CFURLRef mountDir,
                                            (CFStringRef)config.serverConfig.afpUsername, //CFStringRef user,
                                            (CFStringRef)password, //CFStringRef password,
                                            &volRefNum, //FSVolumeRefNum *mountedVolumeRefNum,
                                            kFSMountServerMarkDoNotDisplay //OptionBits flags
                                            );
    
    //TODO: do something with error...
    NSLog(@"FSMountServerVolumeSync user: %@ password: %@ ret: %d",
          config.serverConfig.afpUsername,
          password ? [NSString stringWithFormat:@"(%d chars)", [password length]] : @"(nil)",
          (int)ret);
    
    if (ret != 0)
    {
        // call unmount method with nil so we do the bonjour advertising and alerting thing without attempting an unmount
        [self unmountTMVolumeWithVolumeRefNSNum:nil];
    }
    else
    {
        [self performSelectorOnMainThread:@selector(setProgress:) withObject:[NSNumber numberWithDouble:40] waitUntilDone:NO];
        [addDollyLabel performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Setting Time Machine drive:" waitUntilDone:NO];
        [self setTMVolumeWithVolumeRefNSNum:[NSNumber numberWithInt:(int)volRefNum]];
    }
    
    [pool drain];
}

- (void)setTMVolumeWithVolumeRefNSNum:(NSNumber *)volRefNSNum
{
    FSVolumeRefNum volRefNum = (FSVolumeRefNum)[volRefNSNum intValue];
    
    // find out the mount point
    FSRef mountPointFSRef;
    OSStatus ret = FSGetVolumeInfo(
                                   volRefNum, //FSVolumeRefNum volume,
                                   0, //ItemCount volumeIndex,
                                   NULL, //FSVolumeRefNum *actualVolume,
                                   kFSVolInfoNone, //FSVolumeInfoBitmap whichInfo,
                                   NULL, //FSVolumeInfo *info,
                                   NULL, //HFSUniStr255 *volumeName,
                                   &mountPointFSRef //FSRef *rootDirectory
                                   );
    
    //TODO: do something with error:
    NSLog(@"FSGetVolumeInfo ret: %d", (int)ret);
    if (ret != 0)
    {
        // just unmount and let the volume name checking in unmountTMVolumeWithVolumeRefNSNum: alert the user to manually set volume
        [self unmountTMVolumeWithVolumeRefNSNum:volRefNSNum];
    }
    else
    {
        NDAlias *mountAlias = [NDAlias aliasWithFSRef:&mountPointFSRef];
        
        NSLog(@"mount path: %@", [mountAlias path]);
        
        Class appleTMSettingsClass = NSClassFromString(@"AppleTMSettings");
        
        AppleTMSettings *settings = [appleTMSettingsClass sharedSettings];
        
#ifndef __clang_analyzer__
        [settings retain]; // this is not really a leak since it's a singleton, and it prevents 
                           // an issue where TM prematurely releases it after setting the backup path
#endif
        
        NSError *error = nil;
        
        BOOL TMret = [settings setBackupPath:[mountAlias path] error:&error];
        
        NSLog(@"setBackupPath: TMret: %@ error: %@", TMret ? @"YES" : @"NO", error);
        
        // no need to do anything with this error - if the correct volume has not been chosen an error will be raised in unmountTMVolumeWithVolumeRefNSNum:
        [self performSelectorOnMainThread:@selector(setProgress:) withObject:[NSNumber numberWithDouble:80.0] waitUntilDone:NO];
                
        [self unmountTMVolumeWithVolumeRefNSNum:volRefNSNum];
    }
}

- (void)unmountTMVolumeWithVolumeRefNSNum:(NSNumber *)volRefNSNum
{
    if (volRefNSNum)
    {
        [addDollyLabel performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Unmounting Dolly Drive:" waitUntilDone:NO];
        
        FSVolumeRefNum volRefNum = (FSVolumeRefNum)[volRefNSNum intValue];

        pid_t dissenter = 0;
        OSStatus ret = FSUnmountVolumeSync (
                                            volRefNum, //FSVolumeRefNum vRefNum,
                                            0, //OptionBits flags,
                                            &dissenter //pid_t *dissenter
                                            );
    
        NSLog(@"FSUnmountVolumeSync ret: %d dissenter: %d", (int)ret, dissenter);
        //TODO: if failed, give option to retry
    }
    
    // wait a second to make sure the volume name change has registered
    sleep(1);
    
    NSString *configVolumeName = [ADDAppConfig sharedAppConfig].serverConfig.afpVolumeName;
    // should be updated by now
    if ([self.volumeName isEqualToString:configVolumeName])
    {
        [self performSelectorOnMainThread:@selector(setProgress:) withObject:[NSNumber numberWithDouble:100.0] waitUntilDone:NO];
        [self performSelectorOnMainThread:@selector(finishSettingVolumeWithErrorString:) withObject:nil waitUntilDone:NO];
    }
    else
    {
         ADDBonjour *b = [[[ADDBonjour alloc] init] autorelease];
         if (![b regService])
         {             
             NSString *errorString = [NSString stringWithFormat:@"The correct Volume was not chosen by Time Machine and was unable to be advertised as a Time Machine share with Bonjour. Please contact Dolly Drive support using the \"Send Feedback…\" menu item which will send your error logs to the support team.", configVolumeName];
             [self performSelectorOnMainThread:@selector(finishSettingVolumeWithErrorString:) withObject:errorString waitUntilDone:NO];
         }
         else
         {
             NSString *errorString = [NSString stringWithFormat:@"The correct Volume was not chosen by Time Machine. %@ is now advertised as a bonjour share so you can select it manually in the Time Machine Preferences", configVolumeName];
             [self performSelectorOnMainThread:@selector(finishSettingVolumeWithErrorString:) withObject:errorString waitUntilDone:NO];
         }
    }
}

- (void)finishSettingVolumeWithErrorString:(NSString *)errorString
{
    [addDollyProgress stopAnimation:self];
    [NSApp endSheet:progressSheet];
    [progressSheet orderOut:self];
    
    if (errorString)
    {
        [self performSelector:@selector(finishSettingVolumeWithErrorString2:) withObject:errorString afterDelay:0.1];
    }
}

- (void)finishSettingVolumeWithErrorString2:(NSString *)errorString
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Failed to set Dolly Drive as your Time Machine volume"];
    [alert setInformativeText:errorString];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[self.windowController window]
                      modalDelegate:nil
                     didEndSelector:NULL
                        contextInfo:nil];
}

#pragma mark -
#pragma mark IBActions

- (IBAction) setVolume:(id)sender
{    
    // stop time machine
    NSButton *offButton = [tmPrefPaneObject valueForKey:@"_offButton"];
    [[offButton target] performSelector:[offButton action] withObject:offButton];
        
    [NSApp beginSheet:progressSheet modalForWindow:self.windowController.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    
    [addDollyProgress setDoubleValue:10];
    [addDollyLabel setStringValue:@"Mounting Dolly Drive:"];
    [addDollyProgress startAnimation:self];
    
    [self performSelectorInBackground:@selector(mountTMVolume) withObject:nil];
    
    [scheduleConfigBox setHidden:NO];
    [addDollyBox setHidden:YES];
}

- (IBAction)editExclusions:(id)sender
{
    NSButton *optionsButton = [tmPrefPaneObject valueForKey:@"_optionsButton"];
    [[optionsButton target] performSelector:[optionsButton action] withObject:optionsButton];
}

- (IBAction)showAssistant:(id)sender
{
    if (!self.exclusionsWindowController)
    {
        self.exclusionsWindowController = [[ADDExclusionsWindowController alloc] init];
        [self.exclusionsWindowController showWindow:self];
        [self.exclusionsWindowController close];
    }
    
    
    // TM shouldn't be able to auto-start while the assistant is open (since if someone is
    // there to disable backing up a big folder, don't want to start backing up in the mean time)
    // but don't touch if there is a backup running
    if ([self TMisOn])
    {
        TMWasOnBeforeShowingAssistant = YES;
        
        if (![ADDAppConfig sharedAppConfig].backupInProgress)
            [self turnTMOff];
    }
    else 
    {
        TMWasOnBeforeShowingAssistant = NO;
    }
    
    ((ADDExclusionsVC *)self.exclusionsWindowController.viewController).delegate = self;
    SEL selector = @selector(didEndSheet:returnCode:contextInfo:);
    [NSApp beginSheet:[self.exclusionsWindowController window]
       modalForWindow:[self.windowController window]
        modalDelegate:self
       didEndSelector:selector
          contextInfo:nil];
    
    [self.exclusionsWindowController.viewController showOutline];
}

-(void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    [sheet orderOut:nil];
}

- (IBAction)backupNow:(id)sender
{
    [[ADDAppConfig sharedAppConfig] performSelectorInBackground:@selector(forceTMBackupNow) withObject:nil];
}

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
    [_cloneWindowController release], _cloneWindowController = nil;
    [self willChangeValueForKey:@"cloneWindowVisible"];
    [self.cloneWindowController showNewClone];
    [self didChangeValueForKey:@"cloneWindowVisible"];
}

- (IBAction)updateClone:(id)sender
{
    [_cloneWindowController release], _cloneWindowController = nil;
    [self willChangeValueForKey:@"cloneWindowVisible"];
    [self.cloneWindowController showIncremental];
    [self didChangeValueForKey:@"cloneWindowVisible"];
}

- (IBAction)throttleChange:(id)sender
{
    ADDLaunchDManagement *launchDMgmt = [[[ADDLaunchDManagement alloc] init] autorelease];
    //NSLog(@"value=%f", [bandwidthThrottle floatValue]);
    float throttle = [bandwidthThrottle floatValue];
    
    NSString *speed = [NSString stringWithFormat: @"%1.0f", throttle]; 
    
    [self showThrottleSpeed];
    NSDictionary *config = [ADDServerConfig plistDictionaryForThrottlerConfigWithSpeed:speed andState:throttleOn]; 
    
    [launchDMgmt unloadThrottlerLaunchDaemon];
    
    [config  writeToFile:[ADDServerConfig throttleConfigPath] atomically:YES];

    [launchDMgmt loadThrottlerLaunchDaemon];

}

- (void) showThrottleSpeed
{
    NSString *numberString;
    
    NSString *speed = [bandwidthThrottle stringValue];
    if ([speed isEqualToString:@"0"])
    {
        speed = @"off";
        [bandwidthLabel setStringValue:[NSString stringWithFormat:@"Off"]];
    }
    else
    {
        float throttle = [bandwidthThrottle floatValue];
        NSString *formatString; // = (throttle >= 1024 ? @"%@ Mbps" : @"%@ Kbps");
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




- (IBAction)sliderChange:(id)sender
{
    NSLog(@"value=%f", [slider floatValue]);
    NSString *text = [NSString stringWithFormat:@"Every %i hours", [slider intValue]];
    [applyButton setEnabled:YES];
    [hoursLabel setStringValue:text];
}

- (void) loadSettings
{
    ADDScheduleConfig *config; // = [ADDAppConfig sharedAppConfig].scheduleConfig;
    if ([ADDScheduleConfig configFileExists])
    {
        config = [[ADDScheduleConfig alloc] initFromFile];
    }
    else 
    {
        config = [[ADDScheduleConfig alloc] init];
    }
    [config autorelease];
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm"];  
    [dailyBackupTime  setDateValue:[df dateFromString: config.schedulerDailyStartTime]];
    [dailyOffStartTime  setDateValue:[df dateFromString: config.schedulerOffStartTime]];
    [dailyOffEndTime setDateValue:[df dateFromString: config.schedulerOffEndTime]];
    [df release];
    
    slider.floatValue = [config.interval floatValue];
    [schedOnOffSlider setStateNoAction:config.schedulerActive];
    
    NSInteger tag =  ([config.frequency isEqualToString:@"d"] ? 0 : 1);
    [rdBackupOption selectCellWithTag:tag];
    [chkSkipTimes setState:config.schedulerSkipTimesActive];
    [chkToggleStatus setState:config.schedulerShowInStatusBar];
    [self radioSelected:rdBackupOption];
    [self showLastBackup];

    [self sliderChange:self];
    
    NSDictionary *throttleConfig = [NSDictionary dictionaryWithContentsOfFile:[ADDServerConfig throttleConfigPath]];
    
    // in case old config file version set defaults
    //TODO: version config file
    NSString *speed = [throttleConfig objectForKey:@"speed"];

    [bandwidthThrottle setFloatValue:[[throttleConfig objectForKey:@"speed"] floatValue]];
    [self showThrottleSpeed];

}



- (void) showLastBackup
{
    ADDScheduleConfig *config; // = [ADDAppConfig sharedAppConfig].scheduleConfig;
    if ([ADDScheduleConfig configFileExists])
    {
        config = [[ADDScheduleConfig alloc] initFromFile];
    }
    else 
    {
        config = [[ADDScheduleConfig alloc] init];
    }
    [config autorelease];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    
    if (![config.schedulerLastBackup isEqualToString:@""] && config.schedulerLastBackup != nil)
    {
        NSDate *lastClone = [NSDate dateWithString:config.schedulerLastBackup];
        NSString *localTimeString = [dateFormatter stringFromDate:lastClone];
        [lastBackupLabel setStringValue:localTimeString];
    }
    
    if (config.schedulerActive)
    {
        NSDate *nextClone = config.nextCloneDate; //[NSDate dateWithString:config.schedulerNextClone];
        NSString *localTimeString = [dateFormatter stringFromDate:nextClone];
        [nextCloneLabel setStringValue:localTimeString];
    }
    else
    {
        [nextCloneLabel setStringValue:@""];
    }
    
    [dateFormatter release];
}

- (IBAction)radioSelected:(id)sender
{
    NSInteger tag =  [sender selectedTag];
    [slider setEnabled:(tag == 1)];
    [chkSkipTimes setEnabled:(tag == 1)];
    [dailyBackupTime setEnabled:(tag == 0)];
    //[dailyBackupTime set
    [dailyOffStartTime setEnabled:(tag == 1)];
    [dailyOffEndTime setEnabled:(tag == 1)];
    [applyButton setEnabled:YES];
}

- (IBAction)toggleStatus:(id)sender
{
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    
    //config.schedulerShowInStatusBar = [chkToggleStatus state];
    if ([sender state])
        CFNotificationCenterPostNotification(center, CFSTR("dollyclonescheduler.statuson"), NULL, NULL, TRUE);
    else
        CFNotificationCenterPostNotification(center, CFSTR("dollyclonescheduler.statusoff"), NULL, NULL, TRUE);    
    
    [self applyChanges:self];
}

- (IBAction)settingsChanged:(id)sender
{
    [applyButton setEnabled:YES];
}

- (IBAction)applyChanges:(id)sender
{
    ADDScheduleConfig *config;
    if ([ADDScheduleConfig configFileExists])
    {
        config = [[ADDScheduleConfig alloc] initFromFile];
    }
    else 
    {
        config = [[ADDScheduleConfig alloc] init];
    }
    [config autorelease];
    
    config.interval = [NSNumber numberWithInt:[slider intValue]];
    config.schedulerActive = [schedOnOffSlider state];
    config.schedulerShowInStatusBar = [chkToggleStatus state];
    config.schedulerSkipTimesActive = [chkSkipTimes state];
    
    NSInteger tag =  [rdBackupOption selectedTag];
    config.frequency = (tag == 0 ? @"d" : @"h");
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm"];   
    config.schedulerDailyStartTime = [df stringFromDate:[dailyBackupTime dateValue]];
    config.schedulerOffStartTime = [df stringFromDate:[dailyOffStartTime dateValue]];
    config.schedulerOffEndTime = [df stringFromDate:[dailyOffEndTime dateValue]];
    [df release];
    
    if (!cloneInProgress) 
    {
        if (!scheduleOn)
            [cloneStatusLabel setStringValue:@"Waiting"];
        else
            [cloneStatusLabel setStringValue:@"Not Scheduled"];
    }
    
    //NSNotification *notif;
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    
    if (config.schedulerActive)
        CFNotificationCenterPostNotification(center, CFSTR("dollyclonescheduler.on"), NULL, NULL, TRUE);
    else
        CFNotificationCenterPostNotification(center, CFSTR("dollyclonescheduler.off"), NULL, NULL, TRUE);
    
    [config saveToFile];
    [self showLastBackup];
    [applyButton setEnabled:NO];
    
}


-(IBAction)schedSliderChanged:(id)sender
{    
    scheduleOn = ![schedOnOffSlider state];
    [applyButton setEnabled:YES];
    /*
    if (!cloneInProgress) 
    {
        if (!scheduleOn)
            [cloneStatusLabel setStringValue:@"Waiting"];
        else
            [cloneStatusLabel setStringValue:@"Not Scheduled"];
    }
     */
}


- (void)cloneWindowWillClose
{
    
}

- (BOOL)cloneWindowVisible
{
    if (_cloneWindowController == nil) return NO;
    
    return [self.cloneWindowController.window isVisible];
}


- (IBAction)enterTimeMachine:(id)sender
{
    [[NSWorkspace sharedWorkspace] launchApplication:@"Time Machine"];
}

#pragma mark -
#pragma mark ADDExclusionVCDelegate methods

- (void)exclusionsDidSave
{
    // don't touch if there is currently a backup in progress
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    if (!appConfig.backupInProgress)
    {
        if ([appConfig isFirstRun] || TMWasOnBeforeShowingAssistant)
            [self turnTMOn];
    
        if ([appConfig isFirstRun] && ! appConfig.firstRunBackupStarted)
        {
            [appConfig performSelectorInBackground:@selector(forceTMBackupNow) withObject:nil];
            appConfig.firstRunBackupStarted = YES;
        }
    }
}

- (void)exclusionsDidCancel
{
    // don't touch if there is currently a backup in progress
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    if (!appConfig.backupInProgress)
    {        
        if (TMWasOnBeforeShowingAssistant)
            [self turnTMOn];
    }
}

#pragma mark -
#pragma mark Cleanup

- (void)dealloc
{
    // remove observers
    [[self updateTMName] removeObserver:self forKeyPath:@"stringValue"];
        
    if ([tmPrefPaneObject shouldUnselect] != NSUnselectLater)
    {
        DollyDriveAppAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [appDelegate setTMPrefPaneObject:nil];
        [tmPrefPaneObject willUnselect];
        [tmPrefPaneView removeFromSuperview];
        [tmPrefPaneObject didUnselect];
    }
    
    ReleaseAndNil(exclusionsWindowController);
    
    [super dealloc];
}

@end
