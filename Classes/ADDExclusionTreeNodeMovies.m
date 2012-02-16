//
//  ADDExclusionTreeNodeMovies.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeMovies.h"

#import "ADDExclusionTreeNodeUser.h"
/*
 * NB: self.parent is always an ADDExclusionTreeNodeUser
 */

@implementation ADDExclusionTreeNodeMovies

NSOperationQueue *_ADDExclusionTreeNodeMoviesdiskSizeQueue;

+ (void)initialize
{
    if (!_ADDExclusionTreeNodeMoviesdiskSizeQueue)
    {
        // separate queue for volumes
        _ADDExclusionTreeNodeMoviesdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodeMoviesdiskSizeQueue setMaxConcurrentOperationCount:4];
        [_ADDExclusionTreeNodeMoviesdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodeMoviesdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodeMoviesdiskSizeQueue;
}


- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    NSString *moviesPath = [NSHomeDirectoryForUser([((ADDExclusionTreeNodeUser *)theParent).user posixName]) stringByAppendingPathComponent:@"Movies"];
    
    return [super initWithParent:theParent path:moviesPath];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice documents icon - if it's in a header it's not private right?
    // not in 10.5 IconsCore.h though, need to test the icon exists: kToolbarDocumentsFolderIcon = 'tDoc'
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('tMov')];
}

@end
