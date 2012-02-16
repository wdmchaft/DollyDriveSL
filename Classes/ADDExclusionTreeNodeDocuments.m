//
//  ADDExclusionTreeNodeDocuments.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeDocuments.h"

#import "ADDExclusionTreeNodeUser.h"
/*
 * NB: self.parent is always an ADDExclusionTreeNodeUser
 */


@implementation ADDExclusionTreeNodeDocuments

NSOperationQueue *_ADDExclusionTreeNodeDocumentsdiskSizeQueue;

+ (void)initialize
{
    if (!_ADDExclusionTreeNodeDocumentsdiskSizeQueue)
    {
        // separate queue for volumes
        _ADDExclusionTreeNodeDocumentsdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodeDocumentsdiskSizeQueue setMaxConcurrentOperationCount:4];
        [_ADDExclusionTreeNodeDocumentsdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodeDocumentsdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodeDocumentsdiskSizeQueue;
}


- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    NSString *documentsPath = [NSHomeDirectoryForUser([((ADDExclusionTreeNodeUser *)theParent).user posixName]) stringByAppendingPathComponent:@"Documents"];

    return [super initWithParent:theParent path:documentsPath];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice documents icon - if it's in a header it's not private right?
    // not in 10.5 IconsCore.h though, need to test the icon exists: kToolbarDocumentsFolderIcon = 'tDoc'
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('tDoc')];
}


@end
