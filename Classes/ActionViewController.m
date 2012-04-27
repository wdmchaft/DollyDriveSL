//
//  ActionViewController.m
//  DollyDriveApp
//
//  Created by Angelone John on 10/25/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ActionViewController.h"
//#import "AccountController.h"
#import "MGAViewController.h"
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
#include "ImageTextCell.h"
#include "ADDAppServices.h"
#include "MGAGrepTask.h"
#include "ADDLaunchDManagement.h"
#import "SpeedControlViewController.h"
#import "AccountViewController.h"

/*  this entire module needs to be refactored to have each service (TM, Clone, Account) seprataed into separated NIB files */
 
 
@interface ActionViewController (Private)

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

void *DDTMPrefPaneNameFieldObserver = (void *)@"ADDTMPrefPaneNameFieldObserver";
void *DDTMPrefPaneOldestBackupFieldObserver = (void *)@"ADDTMPrefPaneOldestBackupFieldObserver";
void *DDTMPrefPaneLatestBackupFieldObserver = (void *)@"ADDTMPrefPaneLatestBackupFieldObserver";
void *DDTMPrefPaneNextBackupFieldObserver = (void *)@"ADDTMPrefPaneNextBackupFieldObserver";
void *DDTMPrefPaneProgressTextFieldObserver = (void *)@"ADDTMPrefPaneProgressTextFieldObserver";
void *DDTMPrefPaneProgressIndicatorObserver = (void *)@"ADDTMPrefPaneProgressIndicatorObserver";


@implementation ActionViewController

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
@synthesize hoursLabel, scheduleOn, dailyOffStartTime, dailyOffEndTime, lastBackupLabel, nextCloneLabel, dollyUsage, dailyBackupTime, cloneProgress, cloneInProgress; //throttleOn
//@synthesize bandwidthThrottle;
@synthesize currentView;
@synthesize accountView;
@synthesize advancedView, throttleView;
@synthesize timeMachineView;
@synthesize cloneView, actionArray;

const NSString *DDSchedulerOnNotification = @"dollyclonescheduler.on";
const NSString *DDSchedulerOffNotification = @"dollyclonescheduler.off";
const NSString *DDSchedulerStartNotification = @"dollyclonescheduler.start";
const NSString *DDSchedulerStopNotification = @"dollyclonescheduler.stop";
const NSString *DDSchedulerProgressNotification = @"dollyclonescheduler.progress";
const NSString *DDSchedulerPausedNotification = @"dollyclonescheduler.paused";

void DollyDriveNotificationCenterCallBack(CFNotificationCenterRef center,
                                     void *observer,
                                     id name,
                                     const void *object,
                                     CFDictionaryRef userInfo)
{
    //NSLog(@"clone notification %@", name);
    
    // DSCloneTask *task = (DSCloneTask *)object;
    if ([name isEqual:DDSchedulerProgressNotification] )
    {
        //DSCloneTask *task = (DSCloneTask *)CFDictionaryGetValue(userInfo, CFSTR("task"));
        [(id)observer updateCloneProgress];
    }
    if ([name isEqual:DDSchedulerStartNotification])
    {
        [(id)observer showCloneProgressBar];
    }
    if ([name isEqual:DDSchedulerStopNotification])
    {
        [(id)observer hideCloneProgressBar];
    }
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {

        
        // Initialization code here.
       // AccountController *accountView = [[AccountController alloc] initWithNibName:nil bundle:nil];
       // throttleView = [[SpeedControlViewController alloc] initWithNibName:nil bundle:nil];
        
        [self.currentView  addSubview:accountView];
        [self.currentView  addSubview:cloneView];
        [self.currentView  addSubview:throttleView]; //advancedView
         [self.currentView  addSubview:timeMachineView];
        
        //[cloneView setHidden:YES];
        //currentView = accountView;
    }

    return self;
}


- (void)awakeFromNib
{
    SpeedControlViewController *throttleViewController = [[SpeedControlViewController alloc] init];
    throttleView = [throttleViewController tabView];
    
    
    //AccountViewController *accountViewController = [[AccountViewController alloc] init];
    //accountView = [accountViewController tabView];
    //accountViewController.windowController = self.windowController;
    
    // appList is a NSTableView object
    NSTableColumn* column = [[actionTable tableColumns] objectAtIndex:0];
    ImageTextCell* cell = [[[ImageTextCell alloc] init] autorelease];
    [column setDataCell: cell];
    
    actionArray = [[NSMutableArray alloc] init];
    actionViewArray = [[NSMutableArray alloc] init];
    [cell setPrimaryTextKeyPath: @"displayName"];
    [cell setSecondaryTextKeyPath: @"details"];
    [cell setIconKeyPath: @"icon"];
    
    NSImage *image = [NSImage imageNamed:@"dolly_timemachine"];
    NSDictionary *serviceDict;
    
    serviceDict = [NSDictionary dictionaryWithObjectsAndKeys: @"Time Machine", @"ServiceName", nil];
    ADDAppServices* tmService   = [[[ADDAppServices alloc] initWithInfoDictionary:serviceDict icon:image ] autorelease];
    [actionArray addObject:tmService];
    
    image = [NSImage imageNamed:@"dolly_clone"];
    serviceDict = [NSDictionary dictionaryWithObjectsAndKeys: @"Clone", @"ServiceName", nil];
    ADDAppServices* cloneService   = [[[ADDAppServices alloc] initWithInfoDictionary:serviceDict icon:image ] autorelease];
    [actionArray addObject:cloneService];
    
    image = [NSImage imageNamed:@"dolly_account"];
    serviceDict = [NSDictionary dictionaryWithObjectsAndKeys: @"Account", @"ServiceName", nil];
    ADDAppServices* accountService   = [[[ADDAppServices alloc] initWithInfoDictionary:serviceDict icon:image ] autorelease];
    [actionArray addObject:accountService];
    
    image = [NSImage imageNamed:@"Dolly_Speed"];
    serviceDict = [NSDictionary dictionaryWithObjectsAndKeys: @"Speed Control", @"ServiceName", nil];
    ADDAppServices* advancedService   = [[[ADDAppServices alloc] initWithInfoDictionary:serviceDict icon:image ] autorelease];
    [actionArray addObject:advancedService];
    
    [actionViewArray addObject:timeMachineView];
    [actionViewArray addObject:cloneView];
    [actionViewArray addObject:accountView];
    [actionViewArray addObject:throttleView]; //advancedView];
    [actionTable setDataSource:self]; 
    [actionTable reloadData];
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:0];
    [actionTable selectRowIndexes:indexSet byExtendingSelection:YES];
    
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
        [[self updateTMName] addObserver:self forKeyPath:@"stringValue" options:0 context:DDTMPrefPaneNameFieldObserver];
        [[self updateTMOldestBackup] addObserver:self forKeyPath:@"stringValue" options:0 context:DDTMPrefPaneOldestBackupFieldObserver];
        [[self updateTMLatestBackup] addObserver:self forKeyPath:@"stringValue" options:0 context:DDTMPrefPaneLatestBackupFieldObserver];
        [[self updateTMNextBackup] addObserver:self forKeyPath:@"stringValue" options:0 context:DDTMPrefPaneNextBackupFieldObserver];
        [[self updateProgressTextField] addObserver:self forKeyPath:@"stringValue" options:0 context:DDTMPrefPaneProgressTextFieldObserver];
        id TMprogressIndicator = [self updateProgressIndicator];
        [TMprogressIndicator addObserver:self forKeyPath:@"isIndeterminate" options:0 context:DDTMPrefPaneProgressIndicatorObserver];
        [TMprogressIndicator addObserver:self forKeyPath:@"doubleValue" options:0 context:DDTMPrefPaneProgressIndicatorObserver];
        
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
    
        [self showAction:0];
    
    if (center) {
        
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyDriveNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.progress"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);   
        
        
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyDriveNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.start"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);   
        
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyDriveNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.stop"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);   
        
        CFNotificationCenterAddObserver(center,
                                        self,
                                        (CFNotificationCallback)DollyDriveNotificationCenterCallBack,
                                        CFSTR("dollyclonescheduler.stop"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately); 
    }
    
    //[actionTable setFocusedColumn:0];
}

- (IBAction)actionSelected:(id)sender
{
    //[accountView removeFromSuperview];
    //[self.currentView  addSubview:cloneView];
    NSInteger row = [actionTable clickedRow];
    if (row == -1)
        row = [actionArray count] - 1;
    [self showAction:row];
    //[accountView setHidden:YES];
   // [cloneView setHidden:NO];
}

- (IBAction)showAction:(NSInteger)action
{
    for (NSView *v in  actionViewArray)
    {
        [v setHidden:YES];
    }
    [[actionViewArray objectAtIndex:action] setHidden:NO];
    //[accountView removeFromSuperview];
    //[self.currentView  addSubview:cloneView];
    //int row = [actionTable clickedRow];
    //[accountView setHidden:YES];
    //[cloneView setHidden:NO];
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(int)row
{
    //column identifiers should be the same as the dicionary keys you wish to display
    //you can also store metadata in here as well (file paths, alias data, attributed vs. non-attributed representations...)
    return [actionArray objectAtIndex:row]; // objectForKey:[tableColumn identifier]]; 
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [actionArray count]; // I'll assume both arrays have the same count.
}

- (void)tableView:(NSTableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

}

- (NSInteger)clickedRow
{
    
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
    // update last backup
    if ([ADDScheduleConfig configFileExists])
    {
        ADDScheduleConfig *config = [[[ADDScheduleConfig alloc] initFromFile] autorelease];
        config.schedulerLastBackup = [[NSDate date] description];
        [config saveToFile];
    }
    
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
    if (context == DDTMPrefPaneNameFieldObserver)
        [self updateTMName];
    else if (context == DDTMPrefPaneOldestBackupFieldObserver)
        [self updateTMOldestBackup];
    else if (context == DDTMPrefPaneLatestBackupFieldObserver)
        [self updateTMLatestBackup];
    else if (context == DDTMPrefPaneNextBackupFieldObserver)
        [self updateTMNextBackup];
    else if (context == DDTMPrefPaneProgressTextFieldObserver)
        [self updateProgressTextField];
    else if (context == DDTMPrefPaneProgressIndicatorObserver)
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
    //[tmPrefPaneView setNeedsLayout:YES];
    //[tmPrefPaneView viewWillDraw];
}
/*
-(IBAction)throttleSliderChanged:(id)sender
{    
    throttleOn = [throttleOnOffSlider state];
    [self throttleChange:self];
    //if (!throttleOn)
    //{
      //[bandwidthThrottle setFloatValue:0];
      //[self showThrottleSpeed];
   // }
}
*/
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

- (void) displayAlert:(NSString *)message
{
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  [alert addButtonWithTitle:@"OK"];
  [alert setMessageText:message];
  [alert setAlertStyle:NSWarningAlertStyle];
    
  [alert beginSheetModalForWindow:self.windowController.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {

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
    if ([ADDAppConfig sharedAppConfig].backupInProgress)
    {
        [self displayAlert:@"Time Machine backup in progress, please try again later."];
        return;
    }
  
    
    [_cloneWindowController release], _cloneWindowController = nil;
    [self willChangeValueForKey:@"cloneWindowVisible"];
    [self.cloneWindowController showNewClone];
    [self didChangeValueForKey:@"cloneWindowVisible"];
}

- (IBAction)updateClone:(id)sender
{
    if ([ADDAppConfig sharedAppConfig].backupInProgress)
    {
        [self displayAlert:@"Time Machine backup in progress, please try again later."];
        return;
    }
    
    [_cloneWindowController release], _cloneWindowController = nil;
    [self willChangeValueForKey:@"cloneWindowVisible"];
    [self.cloneWindowController showIncremental];
    [self didChangeValueForKey:@"cloneWindowVisible"];
}
/*
- (IBAction)throttleChange:(id)sender
{
    ADDLaunchDManagement *launchDMgmt = [[[ADDLaunchDManagement alloc] init] autorelease];
    //NSLog(@"value=%f", [bandwidthThrottle floatValue]);
    int tick = [bandwidthThrottle integerValue];
    
    float throttle = 0;
    switch (tick)
    {
        case 0:
            throttle = 256;
            break;
            
        case 22:
            throttle = 10241;
            break;
        default:
            throttle = tick * 512;
    }
    
    
    NSString *speed = [NSString stringWithFormat: @"%1.0f", throttle]; 
    
    [self showThrottleSpeed:throttle];
    NSDictionary *config = [ADDServerConfig plistDictionaryForThrottlerConfigWithSpeed:speed andState:throttleOn]; 
    
    [launchDMgmt unloadThrottlerLaunchDaemon];
    
    [config  writeToFile:[ADDServerConfig throttleConfigPath] atomically:YES];
    
    [launchDMgmt loadThrottlerLaunchDaemon];
    
}

- (void) showThrottleSpeed:(float)throttle
{
    NSString *numberString;
    
    //NSString *speed = [bandwidthThrottle stringValue];
    if (throttle == 10241)
    {
        //speed = @"off";
        [bandwidthLabel setStringValue:[NSString stringWithFormat:@"Unlimited"]];
    }
    else
    {
        //float throttle = [bandwidthThrottle floatValue];
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
       // [bandwidthThrottle setToolTip:[NSString stringWithFormat:formatString, numberString]];

        [bandwidthLabel setStringValue:[NSString stringWithFormat:formatString, numberString]];
    }
}

*/


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
    /*
    NSDictionary *throttleConfig = [NSDictionary dictionaryWithContentsOfFile:[ADDServerConfig throttleConfigPath]];
    NSLog(@"Throttle Config = %@", throttleConfig);
    NSString *speed = [throttleConfig objectForKey:@"speed"];
    throttleOn = (BOOL)[throttleConfig objectForKey:@"throttleOn"];
    [throttleOnOffSlider setState:throttleOn];
    
    float throttle = [speed floatValue];
    int tick = 0;
    if (throttle == 256)
    {
        tick = 0;
    }
    else if (throttle == 10241)
    {
        tick = [bandwidthThrottle maxValue];
    }
    else
    {
        tick = throttle / 512;
    }
        
    [bandwidthThrottle setIntegerValue:tick];
    [self throttleChange:self];
    [self showThrottleSpeed:[speed floatValue]];
     */
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
    [[applyButton cell] setBackgroundColor:[NSColor blueColor]];
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

#pragma mark -
#pragma mark Custom Cell data delegate methods

- (NSImage*) iconForCell: (ImageTextCell*) cell data: (NSObject*) data {
	ADDAppServices* serviceInfo = (ADDAppServices*) data;
	return [serviceInfo icon];
}
- (NSString*) primaryTextForCell: (ImageTextCell*) cell data: (NSObject*) data {
	ADDAppServices* serviceInfo = (ADDAppServices*) data;
	return [serviceInfo displayName];
}
- (NSString*) secondaryTextForCell: (ImageTextCell*) cell data: (NSObject*) data {
	ADDAppServices* serviceInfo = (ADDAppServices*) data;
	return [serviceInfo details];
}

@end

