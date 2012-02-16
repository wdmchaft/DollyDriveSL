/*
 *     Generated by class-dump 3.3.2 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2010 by Steve Nygard.
 */

#import <PreferencePanes/PreferencePanes.h>

#import "DMAsyncDelegate-Protocol.h"

@class DMEraseDisk, DMPartitionDisk, NSButton, NSImage, NSMutableArray, NSString, NSTableView, NSWindow, TMBonjourBrowser, TMPreferencePane;

@interface TMDestinationSheetController : NSObject <DMAsyncDelegate>
{
    TMPreferencePane *_preferencePane;
    NSWindow *_destinationSheet;
    NSTableView *_destinationsTableView;
    NSButton *_okButton;
    NSButton *_cancelButton;
    NSButton *_setUpTimeCapsuleButton;
    NSMutableArray *_destinations;
    TMBonjourBrowser *_bonjourBrowser;
    NSImage *_deleteIcon;
    NSString *_proposedBackupPath;
    unsigned long long _proposedBackupPathConfirmationState;
    BOOL _previousAutoBackupSetting;
    DMEraseDisk *_diskEraser;
    DMPartitionDisk *_diskPartitioner;
    struct __DASession *_daSession;
    BOOL _isPartitioning;
    NSString *_nameOfDiskBeingFormatted;
    NSString *_formatErrorMessage;
    float _formatPercentageComplete;
}

- (void)_authorizeURL:(id)arg1 passwordOnly:(BOOL)arg2 isAirPort:(BOOL)arg3;
- (BOOL)_canVolumeBeReformatted:(id)arg1;
- (void)_cleanUpAfterFormat;
- (void)_deviceConflictAlertDidEnd:(id)arg1 returnCode:(long long)arg2 contextInfo:(void *)arg3;
- (void)_didDismissFileVaultAlert:(id)arg1 returnCode:(long long)arg2 contextInfo:(void *)arg3;
- (struct __DADisk *)_diskForPath:(id)arg1;
- (void)_displayDeviceConflictAlertForSourceDisks:(id)arg1 destinationDisk:(struct __DADisk *)arg2;
- (void)_displayEraseConfirmationAlertForMountPoint:(id)arg1 caseSensitiveIssue:(BOOL)arg2;
- (void)_eraseConfirmationAlertDidEnd:(id)arg1 returnCode:(long long)arg2 contextInfo:(void *)arg3;
- (void)_eraseDisk:(struct __DADisk *)arg1;
- (void)_errorAlertDidEnd:(id)arg1 returnCode:(long long)arg2 contextInfo:(void *)arg3;
- (void)_insufficientAccessAlertDidEnd:(id)arg1 returnCode:(long long)arg2 contextInfo:(void *)arg3;
- (BOOL)_isReformatRequiredForMountPoint:(id)arg1:(char *)arg2;
- (BOOL)_isRepartitionRequiredForDisk:(struct __DADisk *)arg1;
- (BOOL)_isSupportedDestinationAtLocalMountPoint:(id)arg1 readOnly:(BOOL)arg2;
- (BOOL)_isSupportedDestinationAtNetworkMountPoint:(id)arg1;
- (BOOL)_isTimeCapsuleUtilityInstalled;
- (BOOL)_needsCaseSensitiveDestination;
- (id)_networkDestinations;
- (int)_numberOfUserVolumesOnWholeDisk:(struct __DADisk *)arg1;
- (void)_repartitionDisk:(struct __DADisk *)arg1;
- (void)_showAlertForError:(id)arg1;
- (void)_showDestinationSheet:(id)arg1;
- (BOOL)_showFileVaultWarningIfNeeded;
- (id)_sourceDisksConflictingWithDestinationDisk:(struct __DADisk *)arg1;
- (void)bonjourDisksDidChangeNotification:(id)arg1;
- (void)cancelButtonPressed:(id)arg1;
- (BOOL)confirmBackupPath:(id)arg1;
- (void)createDiskArbSession;
- (void)dealloc;
- (void)dmAsyncFinishedForDisk:(struct __DADisk *)arg1 mainError:(int)arg2 detailError:(int)arg3 dictionary:(id)arg4;
- (void)dmAsyncMessageForDisk:(struct __DADisk *)arg1 string:(id)arg2 dictionary:(id)arg3;
- (void)dmAsyncProgressForDisk:(struct __DADisk *)arg1 barberPole:(BOOL)arg2 percent:(float)arg3;
- (void)dmAsyncStartedForDisk:(struct __DADisk *)arg1;
- (void)finalize;
- (float)formatPercentageComplete;
- (void)helpPressed:(id)arg1;
- (void)loadNib;
- (id)nameOfDiskBeingFormatted;
- (long long)numberOfRowsInTableView:(id)arg1;
- (void)okButtonPressed:(id)arg1;
- (void)openTimeCapsuleUtility:(id)arg1;
- (void)showDestinationSheet:(id)arg1;
- (id)tableView:(id)arg1 objectValueForTableColumn:(id)arg2 row:(long long)arg3;
- (id)tableView:(id)arg1 toolTipForCell:(id)arg2 rect:(struct CGRect *)arg3 tableColumn:(id)arg4 row:(long long)arg5 mouseLocation:(struct CGPoint)arg6;
- (void)tableView:(id)arg1 willDisplayCell:(id)arg2 forTableColumn:(id)arg3 row:(long long)arg4;
- (void)tableViewSelectionDidChange:(id)arg1;
- (void)updateButtons;
- (void)updateGUI;
- (void)updateTableViewContents;
- (void)updateTableViewSelection;
- (void)volumesChangedNotification:(id)arg1;

@end
