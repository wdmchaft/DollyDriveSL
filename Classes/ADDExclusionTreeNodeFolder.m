//
//  ADDExclusionTreeNodeFolder.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeFolder.h"


@implementation ADDExclusionTreeNodeFolder

@synthesize baseDir;
@synthesize subDir;

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)path
{
    return [[[self alloc] initWithParent:theParent path:path] autorelease];
}

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent path:(NSString *)path;
{
    if ((self = [super initWithParent:theParent]))
    {
        self.subDir = [path lastPathComponent];
        NSArray *pathComponents = [path pathComponents];
        self.baseDir = [NSString stringWithFormat:@"/%@", [[pathComponents subarrayWithRange:NSMakeRange(0, [pathComponents count]-1)] componentsJoinedByString:@"/"]];
        
        title = [[[NSFileManager defaultManager] displayNameAtPath:path] copy];
    }
    
    return self;
}

- (NSString *)title
{
    return title;
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    return [[NSWorkspace sharedWorkspace] iconForFile:[[(ADDExclusionTreeNodeFolder *)node baseDir] 
                                                       stringByAppendingPathComponent:[(ADDExclusionTreeNodeFolder *)node subDir]]];
}

- (NSString *)representedPath
{
    return [self.baseDir stringByAppendingPathComponent:self.subDir];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: 0x%x> path: %@", [self className], self, [self representedPath]];
}
            
            

- (void)dealloc
{
    ReleaseAndNil(title);
    ReleaseAndNil(baseDir);
    ReleaseAndNil(subDir);
    
    [super dealloc];
}

@end
