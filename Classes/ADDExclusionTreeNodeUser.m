//
//  ADDExclusionTreeUser.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeUser.h"

#import "ADDExclusionTreeNodeDesktop.h"
#import "ADDExclusionTreeNodeDocuments.h"
#import "ADDExclusionTreeNodeMovies.h"
#import "ADDExclusionTreeNodeMusic.h"
#import "ADDExclusionTreeNodePictures.h"
#import "ADDExclusionTreeNodeUserApplications.h"

@implementation ADDExclusionTreeNodeUser

@synthesize user;

NSOperationQueue *_ADDExclusionTreeNodeUserdiskSizeQueue;

+ (void)initialize
{
    if (!_ADDExclusionTreeNodeUserdiskSizeQueue)
    {
        // separate queue for volumes
        _ADDExclusionTreeNodeUserdiskSizeQueue = [[NSOperationQueue alloc] init];
        [_ADDExclusionTreeNodeUserdiskSizeQueue setMaxConcurrentOperationCount:4];
        [_ADDExclusionTreeNodeUserdiskSizeQueue setSuspended:YES];
        [self addQueue:_ADDExclusionTreeNodeUserdiskSizeQueue];
    }
}

+ (NSOperationQueue *)defaultDiskSizeQueue
{
    return _ADDExclusionTreeNodeUserdiskSizeQueue;
}

+ (id)userNodeWithIdentity:(CBIdentity *)theUser
{
    return [[[self alloc] initWithIdentity:theUser] autorelease];
}

- (OSStatus)saveBackupState
{
    return [super saveBackupState];
}

- (NSSet *)userDirsToHideAndExclude
{
    return [NSSet setWithObjects:
            @"/Library/Caches",
            @"/.Trash",
            nil];
}

- (id) initWithIdentity:(CBIdentity *)theUser
{
    if ((self = [super init]))
    {
        self.user = theUser;
        
        [self addChild:[ADDExclusionTreeNodeUserApplications nodeWithParent:self]];
        
        [self addChild:[ADDExclusionTreeNodeDesktop nodeWithParent:self]];
        [self addChild:[ADDExclusionTreeNodeDocuments nodeWithParent:self]];
        [self addChild:[ADDExclusionTreeNodeMovies nodeWithParent:self]];
        [self addChild:[ADDExclusionTreeNodeMusic nodeWithParent:self]];
        [self addChild:[ADDExclusionTreeNodePictures nodeWithParent:self]];
        
        // also add all other dirs - this is almost duplicated code from FolderWithContents :(
        
        NSString *thePath = [self representedPath];
        
        NSSet *manuallyHandledDirs = [NSSet setWithObjects:
                                      [thePath stringByAppendingPathComponent:@"Applications"],
                                      [thePath stringByAppendingPathComponent:@"Documents"],
                                      [thePath stringByAppendingPathComponent:@"Movies"],
                                      [thePath stringByAppendingPathComponent:@"Music"],
                                      [thePath stringByAppendingPathComponent:@"Pictures"],
                                      [thePath stringByAppendingPathComponent:@"Desktop"],
                                      nil];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:2];
        
        NSSet *ignore = [self userDirsToHideAndExclude];
        
        for (NSString *subdir in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:thePath error:NULL])
        {
            BOOL isDirectory = NO;
            NSString *fullPath = [thePath stringByAppendingPathComponent:subdir];
            [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
            
            // seems to auto-skip hidden directories, but just in case
            if (isInvisbleDir(fullPath))
                continue;
            
            if (!isDirectory)
                continue;
            
            if ([self shouldIgnoreDir:fullPath])
                continue;
            
            // ignore the dirs already handled manually above
            
            if ([manuallyHandledDirs containsObject:fullPath])
                continue;
                        
            [queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
                
                int depth = 1;
                NSSet *libraryIgnoredSuffixes = nil;
                
                if ([fullPath hasSuffix:@"/Library"])
                {
                    depth = 0;
                    libraryIgnoredSuffixes = ignore;
                }
                
                ADDExclusionTreeNodeFolder *node = [ADDExclusionTreeNodeFolderWithContents nodeWithParent:self path:fullPath depth:0 maxDepth:depth ignoreSuffixes:libraryIgnoredSuffixes];
                
                // folder inherits default queue from the parent
                node.diskSizeQueue = [[self class] defaultDiskSizeQueue];
                [node queueSetSizeOnDiskIfAllChildrenSized];
            
                [self addChild:node];
            }]];
        }
        
        // make sure the hidden/excluded dirs are excluded
        //TODO: a way to remove this...
        for (NSString *subdir in ignore)
        {
            NSString *fullPathURLString = [thePath stringByAppendingPathComponent:subdir];
            NSURL *fullPathURL = [NSURL URLWithString:fullPathURLString];
            BOOL isDirectory = NO;
                if (
                !fullPathURL ||
                ![[NSFileManager defaultManager] fileExistsAtPath:fullPathURLString isDirectory:&isDirectory]
                )
                continue;

            if (!CSBackupIsItemExcluded (
                                         (CFURLRef)fullPathURL,
                                         NULL //Boolean * excludeByPath
                                         ))
            {
                CSBackupSetItemExcluded (
                                         (CFURLRef)fullPathURL, //CFURLRef item,
                                         true, //Boolean exclude,
                                         true //Boolean excludeByPath
                                         );
            }
        }
        
        [queue waitUntilAllOperationsAreFinished];
        [queue release];
    }
    
    return self;
}

- (NSString *)title
{
    return [self.user posixName];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice desktop icon - if it's in a header it's not private right?
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kToolbarHomeIcon)];
}

- (NSString *)representedPath
{
    return [[NSHomeDirectoryForUser([self.user posixName]) copy] autorelease];
}

@end
