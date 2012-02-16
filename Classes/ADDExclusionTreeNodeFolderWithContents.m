//
//  ADDExclusionTreeNodeFolderWithContents.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeFolderWithContents.h"

#define ADDExclusionTreeNodeFolderWithContents_DEFAULT_MAX_DEPTH 1

@implementation ADDExclusionTreeNodeFolderWithContents

@synthesize depth;

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath
{
    return [self initWithParent:theParent path:thePath depth:0 maxDepth:ADDExclusionTreeNodeFolderWithContents_DEFAULT_MAX_DEPTH];
}

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth
{
    return [[[self alloc] initWithParent:theParent path:thePath depth:theDepth maxDepth:theMaxDepth] autorelease];
}

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth
{
    return [self initWithParent:theParent path:thePath depth:theDepth maxDepth:theMaxDepth ignoreSuffixes:nil];
}

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth ignoreSuffixes:(NSSet *)_ignoreSuffixes
{
    return [[[self alloc] initWithParent:theParent path:thePath depth:theDepth maxDepth:theMaxDepth ignoreSuffixes:_ignoreSuffixes] autorelease];
}

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth ignoreSuffixes:(NSSet *)_ignoreSuffixes
{
    if ((self = [super initWithParent:theParent path:thePath]))
    {
        self.suffixesToIgnore = _ignoreSuffixes;
        self.depth = theDepth;
        
        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        
        BOOL isLibrary = [thePath hasSuffix:@"/Library"];
        
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
            
            ADDExclusionTreeNodeBase *node;
            
            if (
                self.depth < theMaxDepth &&
                ![ws isFilePackageAtPath:fullPath] &&
                !isLibrary
                )
            {
                node = [ADDExclusionTreeNodeFolderWithContents nodeWithParent:self path:fullPath depth:self.depth+1 maxDepth:theMaxDepth];
            }
            else 
            {
                node = [ADDExclusionTreeNodeFolder nodeWithParent:self path:fullPath];
            }
            
            // folder inherits default queue from the parent
            node.diskSizeQueue = [[self class] defaultDiskSizeQueue];

            [node queueSetSizeOnDiskIfAllChildrenSized];
            
            [self addChild:node];
        }
        
        if (!self.children)
            [self queueSetSizeOnDiskIfAllChildrenSized];
    }
    
    return self;    
}

@end
