//
//  ADDExclusionTreeNodeVolumes.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 12/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeVolumes.h"

#import "ADDExclusionTreeNodeVolume.h"
#import "ADDExclusionTreeNodeRootVolume.h"

#include <sys/param.h>
#include <sys/mount.h>

@implementation ADDExclusionTreeNodeVolumes

 NSOperationQueue *_ADDExclusionTreeNodeVolumesdiskSizeQueue;

+ (void)initialize
{
    if (!_ADDExclusionTreeNodeVolumesdiskSizeQueue)
    {
        // separate queue for volumes
        _ADDExclusionTreeNodeVolumesdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodeVolumesdiskSizeQueue setMaxConcurrentOperationCount:2];
        [_ADDExclusionTreeNodeVolumesdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodeVolumesdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodeVolumesdiskSizeQueue;
}

+ (BOOL)hasVolumes
{
    NSArray *volumes = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
    
    for (NSString *path in volumes)
        if (!isInvisbleDir(path))
            return YES;
    
    return NO;
}

+ (id)volumesNode
{
    return [[[self alloc] init] autorelease];
}

BOOL isRealDisk(NSString *mountPath);

BOOL isRealDisk(NSString *mountPath)
{
    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    if (!session) {
        NSLog(@"Can't create DiskArb session...");
        return NO;
    }        
    
    BOOL ret = YES;
    
    struct statfs buf;
    if ((statfs([mountPath UTF8String], &buf)) == 0)
    {
        DADiskRef disk = NULL;
        CFDictionaryRef daDesc = NULL;
        
        disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, buf.f_mntfromname);
        if (!disk)
        {
            CFRelease(session);
            return NO;
        }

        daDesc = DADiskCopyDescription(disk);
        if (!daDesc)
        {
            CFRelease(session);
            CFRelease(disk);
            return NO;
        }
            
        CFStringRef deviceModel = NULL;
        CFBooleanRef isNetwork = NULL;
            
        CFDictionaryGetValueIfPresent(daDesc, kDADiskDescriptionDeviceModelKey, (const void **)&deviceModel);
        CFDictionaryGetValueIfPresent(daDesc, kDADiskDescriptionVolumeNetworkKey, (const void **)&isNetwork);
            
        if ([(NSString *)deviceModel isEqualToString:@"Disk Image"])
        {
            ret = NO;
        }
        else if (isNetwork && CFBooleanGetValue(isNetwork))
        {
            ret = NO;
        }
            
        CFRelease(disk);
        CFRelease(daDesc);
    }
    
    CFRelease(session);
    
    return ret;
}

- (id)init
{
    if ((self = [super init]))
    {
        NSArray *volumes = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
        
        title = [[[NSFileManager defaultManager] displayNameAtPath:@"/Volumes"] copy];
        
        // we can afford to use some parallelism since mostly different volumes will be on
        // different spindles, but don't want to do them all entirely in parallel since
        // in the case there are a bunch of volumes on one disk we would end up thrashing
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:3];
        
        // special entry for root volume
        
        [queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            [self addChild:[ADDExclusionTreeNodeRootVolume nodeWithParent:self path:@"/" depth:0 maxDepth:2]];
        }]];
                
        for (NSString *path in volumes)
        {
            if (isInvisbleDir(path))
                continue;
            
            if (![path hasPrefix:@"/Volumes/"])
                continue;
            
            if ([self shouldIgnoreDir:path])
                continue;
            
            if (!isRealDisk(path))
                continue;
            
            [queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
                [self addChild:[ADDExclusionTreeNodeVolume nodeWithParent:self path:path depth:0 maxDepth:2]];
            }]];
        }
        
        [queue waitUntilAllOperationsAreFinished];
        [queue release];
    }
    
    return self;
}

- (NSString *)title
{
    return title;
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    IconRef icon = NULL;
    GetIconRef( 0, kSystemIconsCreator, kGenericHardDiskIcon, &icon );

    return [[[NSImage alloc] initWithIconRef:icon] autorelease];
}

// We never alter the state of the /Volumes directory directly (doesn't work anyway),
// we alter the backup state of mounted volumes

- (BOOL)isExcludedFromBackup
{
    return NO;
}

- (NSInteger)checkboxState
{
    if ([self allChildrenSelected])
        return NSOnState;
    
    if ([self hasSelectedChildren])
        return NSMixedState;
    
    return NSOffState;
}

- (void)setSizeOnDiskIfAllChildrenSized
{
    BOOL queue = YES;
    
    for (ADDExclusionTreeNodeBase *child in self.children)
    {
        if (!child.sizeOnDisk)
        {
            queue = NO;
            break;
        }
    }
    
    if (queue)
    {
        unsigned long long size = 0;
        for (ADDExclusionTreeNodeBase *child in self.children)
            size += child.sizeOnDisk;
        
        self.sizeOnDisk = size;
        
        NSNotification *notif = [NSNotification notificationWithName:(NSString *)ADDExclusionTreeNodeSizeOnDiskSetNotification object:nil];
        
        if (!operationCancelled)
            [[NSNotificationQueue defaultQueue] enqueueNotification:notif
                                                       postingStyle:NSPostNow];        
    }
}

// the volumes parent is virtual, so we need to bubble writing the backup state down to each volume
// even if all are off
- (OSStatus)saveBackupState
{
    for (ADDExclusionTreeNodeBase *child in self.children)
    {
        OSStatus ret = [child saveBackupState];
        if (ret != noErr)
            return ret;
    }
        
    return noErr;
}


- (void)dealloc
{
    ReleaseAndNil(title);
    
    [super dealloc];
}

@end
