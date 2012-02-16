//
//  ADDExclusionTreeNodePictures.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodePictures.h"

#import "ADDExclusionTreeNodeUser.h"
/*
 * NB: self.parent is always an ADDExclusionTreeNodeUser
 */

@implementation ADDExclusionTreeNodePictures

NSOperationQueue *_ADDExclusionTreeNodePicturesdiskSizeQueue;

+ (void)initialize
{
    if (!_ADDExclusionTreeNodePicturesdiskSizeQueue)
    {
        // separate queue for volumes
        _ADDExclusionTreeNodePicturesdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodePicturesdiskSizeQueue setMaxConcurrentOperationCount:4];
        [_ADDExclusionTreeNodePicturesdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodePicturesdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodePicturesdiskSizeQueue;
}

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    NSString *picturesPath = [NSHomeDirectoryForUser([((ADDExclusionTreeNodeUser *)theParent).user posixName]) stringByAppendingPathComponent:@"Pictures"];
    
    return [super initWithParent:theParent path:picturesPath];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice documents icon - if it's in a header it's not private right?
    // not in 10.5 IconsCore.h though, need to test the icon exists: kToolbarDocumentsFolderIcon = 'tDoc'
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('tPic')];
}

@end
