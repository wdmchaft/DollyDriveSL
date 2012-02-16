//
//  ADDExclusionTreeNodeApplications.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 12/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeApplications.h"


@implementation ADDExclusionTreeNodeApplications

NSOperationQueue *_ADDExclusionTreeNodeApplicationsdiskSizeQueue;

+ (void)initialize
{
    // separate queue for applications
    if (!_ADDExclusionTreeNodeApplicationsdiskSizeQueue)
    {
        _ADDExclusionTreeNodeApplicationsdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodeApplicationsdiskSizeQueue setMaxConcurrentOperationCount:4];
        [_ADDExclusionTreeNodeApplicationsdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodeApplicationsdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodeApplicationsdiskSizeQueue;
}

+ (id)applicationsNode
{
    return [[[self alloc] init] autorelease];
}

- (id)init
{
    NSString *appsPath = @"/Applications";
    
    return [super initWithParent:nil path:appsPath depth:0 maxDepth:2];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice documents icon - if it's in a header it's not private right?
    // not in 10.5 IconsCore.h though, need to test the icon exists: kToolbarDocumentsFolderIcon = 'tDoc'
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('tAps')];
}

@end
