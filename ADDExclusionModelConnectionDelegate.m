//
//  ADDExclusionModelConnectionDelegate.m
//  DollyDriveApp
//
//  Created by System Administrator on 14/06/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADDExclusionModelConnectionDelegate.h"

@implementation ADDExclusionModelConnectionDelegate

NSSet *allowedMessageSelectors = nil;

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedMessageSelectors = [NSSet setWithObjects:
                                   @"_localClassNameForClass",
                                   @"baseDir",
                                   @"checkboxState",
                                   @"children",
                                   @"className",
                                   @"exit",
                                   @"hash",
                                   @"isEqual:",
                                   @"isExpandable",
                                   @"isKindOfClass:",
                                   @"keyedRootObject",
                                   @"methodDescriptionForSelector:",
                                   @"saveBackupStateExcludingRootDirs:WithError:",
                                   @"selected",
                                   @"setSelected:",
                                   @"sizeOnDisk",
                                   @"subDir",
                                   @"title",
                                   @"treeTopLevel",
                                   nil];
    });
}

- (BOOL)connection:(NSConnection *)conn handleRequest:(NSDistantObjectRequest *)doReq
{
    NSInvocation *inv = [doReq invocation];
	NSString *selString = NSStringFromSelector([inv selector]);
    if	(![allowedMessageSelectors containsObject:selString])
    {
        NSLog(@"client sent disallowed message: %@", selString);
        abort();
    }

    return NO;
}

@end
