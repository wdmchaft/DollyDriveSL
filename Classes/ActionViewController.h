//
//  ActionViewController.h
//  DollyDriveApp
//
//  Created by Angelone John on 10/25/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MGAViewController.h"
#import "TMPreferencePane.h"
#import "ADDMainWindowCloneVC.h"
#import "ADDExclusionsWindowController.h"
#import "ADDExclusionsVC.h"

@class TMSliderControl, ADDScheduleConfig, DSCloneTask, SpeedControlViewController;

@interface ActionViewController : MGAViewController <ADDExclusionsVCDelegate, ADDCloneWindowDelegate, NSTableViewDelegate>
{
    IBOutlet NSView *currentView;
    IBOutlet NSView *accountView;
    IBOutlet NSView *cloneView;
    IBOutlet NSView *timeMachineView;
    IBOutlet NSView *advancedView;
    IBOutlet NSTableView *actionTable;
    NSMutableArray *actionArray;
    NSMutableArray *actionViewArray;
    IBOutlet NSView  *throttleView;
    
    IBOutlet NSView *prefPaneHostView;
    TMPreferencePane *tmPrefPaneObject;
    NSView *tmPrefPaneView;    
    
    NSString *volumeName;
    NSString *oldestBackup;
    NSString *nextBackup;
    NSString *latestBackup;
    NSString *progressDescription;
    double progressIndicatorMaxValue;
    double progressIndicatorMinValue;
    double progressIndicatorDoubleValue;
    BOOL progressIndicatorIsIndeterminate;
    BOOL cloneInProgress;
    NSString *shareSizeString;
    
    ADDExclusionsWindowController *exclusionsWindowController;
    ADDMainWindowCloneVC *mainWindowCloneVC;
    
    IBOutlet NSSegmentedControl *onOffControl;
    
    IBOutlet NSView *changeVolumeView;
    IBOutlet NSView *mountHelpView;
    IBOutlet NSView *sizeView;
    
    IBOutlet NSLevelIndicator *dollyUsage;
    IBOutlet NSLevelIndicator *cloneProgress;
    
    BOOL TMWasOnBeforeShowingAssistant;
    BOOL dollyConfigured;
    
    BOOL willPresentChangeView;
    
    IBOutlet NSButton *addDollyNowButton;
    IBOutlet NSTextField *nextBackupLabelTextField;
    IBOutlet NSTextField *nextBackupTextField;
    IBOutlet NSTextField *backupProgressTextField;
    IBOutlet NSProgressIndicator *backupProgressIndicator;
    
    IBOutlet NSProgressIndicator *addDollyProgress;
    IBOutlet NSProgressIndicator *addCloneProgress;
    IBOutlet NSBox *addDollyBox;
    IBOutlet NSBox *scheduleConfigBox;
    IBOutlet NSTextField *addDollyLabel;
    IBOutlet NSPanel *progressSheet;
    IBOutlet NSPanel *addDollySheet;
    
    IBOutlet TMSliderControl* onOffSlider;
    IBOutlet NSButton *ddOnButton;
    IBOutlet NSButton *ddOffButton;
    
    //IBOutlet TMSliderControl* throttleOnOffSlider;
    //IBOutlet NSButton *throttleOnButton;
   // IBOutlet NSButton *throttleOffButton;
    
   // IBOutlet NSSlider *bandwidthThrottle;
    NSTimer *progressTimer;
    
    NSInteger chooseVolumeRetries;
    
    NSImage *alertIconImage;
    NSString *username;    
    
    NSString *_availableSizeString;
    NSString *_usedSizeString;
    
    IBOutlet NSTextField *dollyMiddleValue;
    IBOutlet NSTextField *dollyMaxValue;
    
    ADDCloneWindowController *_cloneWindowController;
    IBOutlet NSImageView *mainLogo;
    IBOutlet NSSlider *slider;
    IBOutlet NSTextField *hoursLabel;
    IBOutlet NSTextField *lastBackupLabel;
    IBOutlet NSTextField *nextCloneLabel;
    IBOutlet NSTextField *popupMessage;
    IBOutlet NSPanel *messageSheet;
    IBOutlet NSTextField *bandwidthLabel;
    IBOutlet NSTextField *cloneStatusLabel;
    ADDScheduleConfig *scheduleConfig;
    IBOutlet TMSliderControl* schedOnOffSlider;
    IBOutlet NSButton *schedOnButton;
    IBOutlet NSButton *schedOffButton;
    IBOutlet NSButton *applyButton;
    IBOutlet NSMatrix *rdBackupOption;
    IBOutlet NSButton *chkToggleStatus;
    IBOutlet NSButton *chkSkipTimes;
    IBOutlet NSDatePicker *dailyBackupTime;
    IBOutlet NSDatePicker *dailyOffEndTime;
    IBOutlet NSDatePicker *dailyOffStartTime;
    
    BOOL scheduleOn;
    //BOOL throttleOn;
}

@property (readonly, retain) ADDCloneWindowController *cloneWindowController;
@property (copy) NSString *volumeName;
@property (copy) NSString *oldestBackup;
@property (copy) NSString *nextBackup;
@property (copy) NSString *latestBackup;
@property (copy) NSString *progressDescription;
@property (assign) double progressIndicatorMaxValue;
@property (assign) double progressIndicatorMinValue;
@property (assign) double progressIndicatorDoubleValue;
@property (assign) BOOL progressIndicatorIsIndeterminate;
@property (assign) BOOL cloneInProgress;
@property (copy) NSString *shareSizeString;
@property (copy) NSString *availableSizeString;
@property (copy) NSString *usedSizeString;
@property (retain) NSTimer *progressTimer;
@property (retain) NSImage *alertIconImage;
@property (assign) BOOL dollyConfigured;
@property (copy) NSString *username;
@property (retain) ADDExclusionsWindowController *exclusionsWindowController;
@property (retain) ADDMainWindowCloneVC *mainWindowCloneVC;

@property (assign) NSTextField *hoursLabel;
@property (assign) NSTextField *lastBackupLabel;
@property (assign) NSTextField *bandwidthLabel;
@property (assign) NSTextField *nextCloneLabel;
@property (assign) NSTextField *cloneStatusLabel;
@property (readonly) ADDScheduleConfig *scheduleConfig;
@property (assign) BOOL scheduleOn;
//@property (assign) BOOL throttleOn;
@property (retain) NSDatePicker *dailyBackupTime;
@property (retain) NSDatePicker *dailyOffEndTime;
@property (retain) NSDatePicker *dailyOffStartTime;
@property (retain)  NSLevelIndicator *dollyUsage;
@property (retain)  NSLevelIndicator *cloneProgress;
//@property (retain)  NSSlider *bandwidthThrottle;
@property  (retain)  NSView *currentView;
@property  (retain)  NSView *accountView;
@property  (retain)  NSView *cloneView;
@property  (retain)  NSView *timeMachineView;
@property  (retain)  NSView *advancedView;
@property  (retain)  IBOutlet NSView  *throttleView;
@property  (retain)  NSMutableArray *actionArray;
@property  (retain)  NSMutableArray *actionViewArray;

- (void) updateCloneProgress;  //:(DSCloneTask*)task;
- (IBAction)radioSelected:(id)sender;
- (IBAction)sliderChange:(id)sender;
- (IBAction)applyChanges:(id)sender;
//- (IBAction)throttleChange:(id)sender;
- (IBAction)schedSliderChanged:(id)sender;
//- (IBAction)throttleSliderChanged:(id)sender;
- (IBAction)tmSliderChanged:(id)sender;
- (IBAction)datePickerAction:(id)sender;
- (IBAction)toggleStatus:(id)sender;
- (IBAction)settingsChanged:(id)sender;
- (IBAction)newClone:(id)sender;
- (IBAction)updateClone:(id)sender;
- (void) showLastBackup;
//- (void) showThrottleSpeed:(float)throttle;
- (void) displayAlert:(NSString *)message;



- (IBAction)tmSliderChanged:(id)sender;
- (IBAction)turnBackupsOn:(id)sender;
- (IBAction)turnBackupsOff:(id)sender;
- (IBAction)editExclusions:(id)sender;
- (IBAction)setVolume:(id)sender;
- (IBAction)showAssistant:(id)sender;
- (IBAction)backupNow:(id)sender;
- (IBAction)enterTimeMachine:(id)sender;
- (IBAction)restoreTMPlist:(id)sender;
- (IBAction)changeUser:(id)sender;
- (IBAction)accountDetails:(id)sender;
- (IBAction)actionSelected:(id)sender;
- (IBAction)showAction:(NSInteger)action;

- (void) loadSettings;
- (void) showCLoneProgressBar;
- (void) hideCLoneProgressBar;

extern const NSString *DDSchedulerOnNotification;
extern const NSString *DDSchedulerOffNotification;


@end