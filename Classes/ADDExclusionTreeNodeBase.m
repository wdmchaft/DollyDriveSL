//
//  ADDExclusionTreeBase.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeBase.h"

#import "MGAFastFolderSize.h"
#import "MGAThreadSafeMutableDictionary.h"
#import "ADDExclusionsModel.h" // for the exclude/removeExclusion functions

#define ADDExclusionTreeNodeBaseSmallIconHeight 32
#define ADDExclusionTreeNodeBaseSmallIconWidth 32

const NSString *ADDExclusionTreeNodeSizeOnDiskSetNotification = @"ADDExclusionTreeNodeSizeOnDiskSetNotification";

@interface ADDExclusionTreeNodeBase (Private)

- (void)setSizeOnDisk;
- (void)setSelectedNoUpherit:(BOOL)sel;

@end

@implementation ADDExclusionTreeNodeBase

@synthesize children;
@synthesize parent;
@synthesize sizeOnDisk;
@synthesize diskSizeQueue;
@synthesize suffixesToIgnore;

NSOperationQueue *_diskSizeQueue;
MGAThreadSafeMutableDictionary *_diskSizeCache;
NSMutableArray *_queuesArray;

+ (void)initialize
{
    if (!_queuesArray)
        _queuesArray = [[NSMutableArray alloc] initWithCapacity:5];
    if (!_diskSizeQueue)
    {
        _diskSizeQueue = [[NSOperationQueue alloc] init];
        [_diskSizeQueue setMaxConcurrentOperationCount:4];
        
        // queue starts suspendded
        [_diskSizeQueue setSuspended:YES];
        
        [self addQueue:_diskSizeQueue];
    }
    
    if (!_diskSizeCache)
        _diskSizeCache = [[MGAThreadSafeMutableDictionary alloc] initWithCapacity:1000];
}

+ (void)addQueue:(NSOperationQueue *)queue
{
    [_queuesArray addObject:queue];
}

+ (void)cancelAllQueues
{
    for (NSOperationQueue *q in _queuesArray)
        [q cancelAllOperations];
}

+ (void)setAllQueuesSuspended:(BOOL)s
{
    for (NSOperationQueue *q in _queuesArray)
        [q setSuspended:s];
}

+ (void)waitForAllQueuesToFinish
{
    for (NSOperationQueue *q in _queuesArray)
        [q waitUntilAllOperationsAreFinished];
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _diskSizeQueue;
}

+ (NSMutableDictionary *)diskSizeCache
{
    return _diskSizeCache;
}

// http://www.thohensee.com/?p=329
BOOL isInvisibleCFURL(CFURLRef inURL)
{
    LSItemInfoRecord itemInfo;
    LSCopyItemInfoForURL(inURL, kLSRequestAllFlags, &itemInfo);
    
    BOOL isInvisible = itemInfo.flags & kLSItemInfoIsInvisible;
    return isInvisible;
}

BOOL isInvisbleDir(NSString *path)
{
    CFURLRef url = CFURLCreateWithFileSystemPath (
                                                  NULL, //CFAllocatorRef allocator,
                                                  (CFStringRef)path, //CFStringRef filePath,
                                                  kCFURLPOSIXPathStyle, //CFURLPathStyle pathStyle,
                                                  true //Boolean isDirectory
                                                  );
    
    BOOL ret = isInvisibleCFURL(url);
    
    CFRelease(url);
    
    return ret;
}

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    return [[[self alloc] initWithParent:theParent] autorelease];
}

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    if ((self = [super init]))
    {
        self.parent = theParent;
    }
    
    return self;
}

- (void)addChild:(ADDExclusionTreeNodeBase *)child
{
    if (!self.children)
        self.children = [NSMutableArray arrayWithCapacity:5];

    // assuming parent is already set
    [self.children addObject:child];
}

- (NSInteger)checkboxState
{
    if (![self.children count])
    {
        if (self.selected)
            return NSOnState;
    }
    else
    {
        if ([self allChildrenSelected])
            return NSOnState;
    }
    
    if ([self hasSelectedChildren])
        return NSMixedState;
    
    return NSOffState;
}

- (NSString *)representedPath
{
    return nil;
}

- (CFURLRef)representedCFURL
{
    if (!representedCFURL && [self representedPath])
        representedCFURL = CFURLCreateWithFileSystemPath (
                                                          NULL, //CFAllocatorRef allocator,
                                                          (CFStringRef)[self representedPath], //CFStringRef filePath,
                                                          kCFURLPOSIXPathStyle, //CFURLPathStyle pathStyle,
                                                          true //Boolean isDirectory
                                                          );
    
    return representedCFURL;
}

- (void)queueSetSizeOnDiskIfAllChildrenSized
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
        NSOperationQueue *q = self.diskSizeQueue ? self.diskSizeQueue : [[self class] defaultDiskSizeQueue];
        NSInvocationOperation *op = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(setSizeOnDisk) object:nil] autorelease];
        [op addObserver:self forKeyPath:@"isCancelled" options:NSKeyValueObservingOptionNew context:nil];
        [q addOperation:op];
    }
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
        [self setSizeOnDisk];
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isKindOfClass:[NSInvocationOperation class]] && [(NSInvocationOperation *)object isCancelled])
        operationCancelled = YES;
}

- (void)setSizeOnDisk
{
    if (operationCancelled)
        return;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if (![self representedPath])
        return;
    
    unsigned long long ret = MGAFastFolderSizeForPathWithCache([self representedPath], [[self class] diskSizeCache], &operationCancelled);
    
    //TODO: better
    if (ret == MGAFastFolderSizeErr)
        ret = 0; // probablly does not exist
    
    if (ret != MGAFastFolderSizeNoValue && ret != MGAFastFolderSizeErr && !operationCancelled)
    {
        self.sizeOnDisk = ret;
    
        // rather than tracking a bool, make minimum size 1
        if (self.sizeOnDisk == 0)
            self.sizeOnDisk = 1;
    
        NSNotification *notif = [NSNotification notificationWithName:(NSString *)ADDExclusionTreeNodeSizeOnDiskSetNotification object:nil];
    
        [[NSNotificationQueue defaultQueue] enqueueNotification:notif
                                                   postingStyle:NSPostNow];
        
        [[[self class] diskSizeCache] setObject:[NSNumber numberWithUnsignedLongLong:self.sizeOnDisk] forKey:[self representedPath]];
    
        [self.parent setSizeOnDiskIfAllChildrenSized]; // if all children are sized it should be pretty quick
    }
    
    [pool drain];
}

- (BOOL)isExcludedFromBackup
{
    if ([self representedCFURL])
        return CSBackupIsItemExcluded([self representedCFURL], NULL) ? YES : NO;
    else 
        return NO;
}

- (BOOL)shouldIgnoreDir:(NSString *)path
{
    // hide anything that has the metadata exclusion (eg. things like iTunes cache)

    CFURLRef url = CFURLCreateWithFileSystemPath (
                                                  NULL, //CFAllocatorRef allocator,
                                                  (CFStringRef)path, //CFStringRef filePath,
                                                  kCFURLPOSIXPathStyle, //CFURLPathStyle pathStyle,
                                                  true //Boolean isDirectory
                                                  );
    
    Boolean excludeByPath = false;
    Boolean isItemExcluded = CSBackupIsItemExcluded(url, &excludeByPath);
    CFRelease(url);
    
    if (!isItemExcluded)
        return NO;
    
    if (!excludeByPath)
        return YES;
    
    if (self.suffixesToIgnore)
    {
        for (NSString *suffix in self.suffixesToIgnore)
        {
            if ([path hasSuffix:suffix])
                return YES;
        }
    }
    
    return NO;
}

- (void)updateBackupStatus
{
    if ([self isExcludedFromBackup])
    {
        [self setSelectedNoUpherit:NO];
    }
    else
    {
        [self setSelectedNoUpherit:YES];
        for (ADDExclusionTreeNodeBase *child in children)
        {
            [child updateBackupStatus];
        }
    }
}

- (OSStatus)saveBackupState
{
    if (self.selected || [self hasSelectedChildren])
    {
        // selected - ie. do not exclude from backup
        
        if ([self isExcludedFromBackup])
        {
            OSStatus ret = [self removeExclusion];

            if (ret != noErr)
            {
                NSLog(@"error %d (%s) removing exclusion for %@", (int)ret, GetMacOSStatusErrorString(ret), self);
                return ret;
            }
        }
        
        for (ADDExclusionTreeNodeBase *child in children)
        {
            OSStatus ret = [child saveBackupState];

            if (ret != noErr)
                return ret;
        }
    }
    else 
    {
        // not selected for backup, ie. exclude from backup
        
        if (![self isExcludedFromBackup])
        {
            OSStatus ret = [self excludeFromBackup];
        
            if (ret != noErr)
            {
                NSLog(@"error %d (%s) adding exclusion for %@", (int)ret, GetMacOSStatusErrorString(ret), self);
                return ret;
            }
        }
    }
    
    return noErr;
}


- (OSStatus)excludeFromBackup
{
    if ([self isExcludedFromBackup])
        return noErr;
    
    return excludePath([self representedPath]);
}


- (OSStatus)removeExclusion
{
    
    if (![self isExcludedFromBackup])
        return noErr;
    
    return removeExclusionForPath([self representedPath]);
}



- (BOOL)hasSelectedChildren
{
    if (!children)
        return NO;
    
    for (ADDExclusionTreeNodeBase *node in children)
    {
        if (node.selected || [node hasSelectedChildren])
            return YES;
    }
    
    return NO;
}

- (BOOL)allChildrenSelected
{
    if (!children)
        return YES;
    
    for (ADDExclusionTreeNodeBase *node in children)
    {
        if (!node.selected || ![node allChildrenSelected])
            return NO;
    }
    
    return YES;    
}

- (BOOL)selected
{    
    return selected;
}

- (void)upheritSelection
{
    if (children && [children count] && ![self allChildrenSelected])
    {
        selected = NO;
        [self.parent upheritSelection];
    }
    else if (children && [children count] && [self allChildrenSelected])
    {
        selected = YES;
        [self.parent upheritSelection];
    }
}

- (void)setSelectedNoUpherit:(BOOL)sel
{
    selected = sel;
    [self setChildrenSelected:sel];
}

- (void)setSelected:(BOOL)sel
{
    [self setSelectedNoUpherit:sel];
    [self.parent upheritSelection];
}

- (void)setChildrenSelected:(BOOL)sel
{
    if (children)
    {
        for (ADDExclusionTreeNodeBase *node in children)
        {
            [node setSelectedNoUpherit:sel];
            [node setChildrenSelected:sel];
        }
    }
}

- (BOOL)isExpandable
{
    return children && [children count] ? YES : NO;
}

- (NSString *)title
{
    return @"Base class!";
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    return nil;
}

+ (NSImage *)smallIconForNode:(ADDExclusionTreeNodeBase *)node
{
    NSImage *icon = [self iconForNode:node];
    NSImage *smallIcon = nil;
    
    if (!icon)
        return nil;
    
    NSSize iconSize = [icon size];
    
    if (
        iconSize.height <= ADDExclusionTreeNodeBaseSmallIconHeight &&
        iconSize.width <= ADDExclusionTreeNodeBaseSmallIconWidth
        )
    {
        smallIcon = icon;
    }
    else 
    {
        NSSize newIconSize = NSMakeSize(
                                        ADDExclusionTreeNodeBaseSmallIconWidth,
                                        ADDExclusionTreeNodeBaseSmallIconWidth
                                        );
        
        smallIcon = [[[NSImage alloc] initWithSize:newIconSize] autorelease];
        [smallIcon lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [icon setSize:newIconSize];
        [icon compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
        [smallIcon unlockFocus];
    }
    
    return smallIcon;
}

- (NSString *)className
{
    return NSStringFromClass([self class]);
}

- (void)dealloc
{
    for (ADDExclusionTreeNodeBase *child in children)
        [child setParent:nil];
    
    ReleaseAndNil(children);
    ReleaseAndNil(smallIcon);
    
    if (representedCFURL)
        CFRelease(representedCFURL);
    
    [super dealloc];
}

@end
