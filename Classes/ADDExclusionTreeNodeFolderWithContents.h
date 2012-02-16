//
//  ADDExclusionTreeNodeFolderWithContents.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDExclusionTreeNodeFolder.h"

@interface ADDExclusionTreeNodeFolderWithContents : ADDExclusionTreeNodeFolder
{
    NSInteger depth;
}

@property (assign) NSInteger depth;

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth ignoreSuffixes:(NSSet *)_ignoreSuffixes;
- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth ignoreSuffixes:(NSSet *)_ignoreSuffixes;

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth;
- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)thePath depth:(NSInteger)theDepth maxDepth:(NSInteger)theMaxDepth;

@end
