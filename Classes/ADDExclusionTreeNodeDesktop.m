//
//  ADDExclusionTreeNodeDesktop.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeDesktop.h"

#import "ADDExclusionTreeNodeUser.h"
/*
 * NB: self.parent is always an ADDExclusionTreeNodeUser
 */

@implementation ADDExclusionTreeNodeDesktop

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    return [[[self alloc] initWithParent:theParent] autorelease];
}

- (id)initWithParent:(ADDExclusionTreeNodeBase *)theParent
{
    NSString *desktopPath = [NSHomeDirectoryForUser([((ADDExclusionTreeNodeUser *)theParent).user posixName]) stringByAppendingPathComponent:@"Desktop"];
    
    return [super initWithParent:theParent path:desktopPath];
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    // get the nice desktop icon - if it's in a header it's not private right?
    // not in 10.5 IconsCore.h though, need to test the icon exists: kToolbarDesktopFolderIcon = 'tDsk'
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('tDsk')];
}

@end
