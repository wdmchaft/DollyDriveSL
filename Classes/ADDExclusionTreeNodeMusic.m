//
//  ADDExclusionTreeNodeMusic.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeMusic.h"

#import "ADDExclusionTreeNodeUser.h"
/*
 * NB: self.parent is always an ADDExclusionTreeNodeUser
 */

@implementation ADDExclusionTreeNodeMusic

NSOperationQueue *_ADDExclusionTreeNodeMusicdiskSizeQueue;

+ (void)initialize
{
    if (!_ADDExclusionTreeNodeMusicdiskSizeQueue)
    {
        // separate queue for volumes
        _ADDExclusionTreeNodeMusicdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodeMusicdiskSizeQueue setMaxConcurrentOperationCount:4];
        [_ADDExclusionTreeNodeMusicdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodeMusicdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodeMusicdiskSizeQueue;
}


- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    NSString *musicPath = [NSHomeDirectoryForUser([((ADDExclusionTreeNodeUser *)theParent).user posixName]) stringByAppendingPathComponent:@"Music"];
    
    return [super initWithParent:theParent path:musicPath];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice documents icon - if it's in a header it's not private right?
    // not in 10.5 IconsCore.h though, need to test the icon exists: kToolbarDocumentsFolderIcon = 'tDoc'
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('tMus')];
}


@end
