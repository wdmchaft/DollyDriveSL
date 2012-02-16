//
//  ADDExclusionTreeBase.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ADDExclusionTreeNodeBase : NSObject
{
    BOOL selected;
    CFURLRef representedCFURL;
    NSImage *smallIcon;
    BOOL operationCancelled;
    
    NSMutableArray *children; // array of ADDExclusionTreeBase subclasses
    ADDExclusionTreeNodeBase *parent;
    unsigned long long sizeOnDisk;
    NSOperationQueue *diskSizeQueue;
    
    NSSet *suffixesToIgnore;
}

@property (retain) NSMutableArray *children; // array of ADDExclusionTreeBase subclasses
@property (assign) ADDExclusionTreeNodeBase *parent;
@property BOOL selected;
@property (assign) unsigned long long sizeOnDisk;
@property (retain) NSOperationQueue *diskSizeQueue;
@property (retain) NSSet *suffixesToIgnore;

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)parent;
+ (NSOperationQueue *)defaultDiskSizeQueue;
+ (NSMutableDictionary *)diskSizeCache;
+ (void)addQueue:(NSOperationQueue *)queue;
+ (void)cancelAllQueues;
+ (void)setAllQueuesSuspended:(BOOL)s;
+ (void)waitForAllQueuesToFinish;

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node;
+ (NSImage *)smallIconForNode:(ADDExclusionTreeNodeBase *)node;

- (id)initWithParent:(ADDExclusionTreeNodeBase *)parent;

- (NSString *)representedPath;
- (CFURLRef)representedCFURL;
- (BOOL)isExcludedFromBackup;
- (void)updateBackupStatus;
- (OSStatus)saveBackupState;
- (OSStatus)excludeFromBackup; //private
- (OSStatus)removeExclusion; // private
- (BOOL)hasSelectedChildren;
- (BOOL)allChildrenSelected;
- (void)upheritSelection;
- (void)setChildrenSelected:(BOOL)sel;
- (NSInteger)checkboxState;
- (BOOL)isExpandable;
- (NSString *)title;
- (void)addChild:(ADDExclusionTreeNodeBase *)child;
- (BOOL)shouldIgnoreDir:(NSString *)path;
- (void)setSizeOnDisk;
- (void)queueSetSizeOnDiskIfAllChildrenSized;

- (NSString *)className;

BOOL isInvisbleDir(NSString *path);
BOOL isInvisibleCFURL(CFURLRef inURL);

extern const NSString *ADDExclusionTreeNodeSizeOnDiskSetNotification;

@end
