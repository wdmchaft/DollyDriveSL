//
//  ADDExclusionTreeNodeUserApplications.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 12/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeUserApplications.h"

#import "ADDExclusionTreeNodeUser.h"

@implementation ADDExclusionTreeNodeUserApplications

NSOperationQueue *_ADDExclusionTreeNodeUserApplicationsdiskSizeQueue;

+ (void)initialize
{
    if (!_ADDExclusionTreeNodeUserApplicationsdiskSizeQueue)
    {
        // separate queue for volumes
        _ADDExclusionTreeNodeUserApplicationsdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodeUserApplicationsdiskSizeQueue setMaxConcurrentOperationCount:4];
        [_ADDExclusionTreeNodeUserApplicationsdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodeUserApplicationsdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodeUserApplicationsdiskSizeQueue;
}

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    NSString *userAppsPath = [NSHomeDirectoryForUser([((ADDExclusionTreeNodeUser *)theParent).user posixName]) stringByAppendingPathComponent:@"Applications"];
    
    return [super initWithParent:theParent path:userAppsPath depth:0 maxDepth:2];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice documents icon - if it's in a header it's not private right?
    // not in 10.5 IconsCore.h though, need to test the icon exists: kToolbarDocumentsFolderIcon = 'tDoc'
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('tAps')];
}


@end
