//
//  ADDExclusionTreeNodeRootVolume.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/03/11.
//  Copyright 2011 Pumptheory Pty Ltd. All rights reserved.
//

#import "ADDExclusionTreeNodeRootVolume.h"

#import "ADDExclusionsModel.h"

@implementation ADDExclusionTreeNodeRootVolume

- (BOOL)shouldIgnoreDir:(NSString *)path
{
    // don't show the auto-ignored directories or the ones with special handling (eg. Users)
    
    NSSet *ignorePaths = [ADDExclusionsModel ignoredRootDirs];
    
    if ([ignorePaths containsObject:path])
        return YES;
    
    return [super shouldIgnoreDir:path];
}

- (BOOL)isExcludedFromBackup
{
    return NO;
}

- (BOOL)selected
{
    return [self hasSelectedChildren] ? YES : NO;
}

- (NSInteger)checkboxState
{
    if ([self allChildrenSelected])
        return NSOnState;
    
    if ([self hasSelectedChildren])
        return NSMixedState;
    
    return NSOffState;
}

// never want to turn off backing up the entire root volume
- (OSStatus)saveBackupState
{
    for (ADDExclusionTreeNodeBase *child in self.children)
    {
        OSStatus ret = [child saveBackupState];
        if (ret != noErr)
            return ret;
    }
    
    return noErr;
}


@end
