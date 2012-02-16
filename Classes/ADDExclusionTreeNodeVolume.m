//
//  ADDExclusionTreeNodeVolume.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 12/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTreeNodeVolume.h"


@implementation ADDExclusionTreeNodeVolume

// want to exclude volumes by id, not by path
// seems to set the metadata, not sure if that's what we want...

/*
- (OSStatus)excludeFromBackup
{
    return CSBackupSetItemExcluded (
                                    [self representedCFURL], //CFURLRef item,
                                    true, //Boolean exclude,
                                    false //Boolean excludeByPath
                                    );
}

- (OSStatus)removeExclusion
{
    return CSBackupSetItemExcluded (
                                    [self representedCFURL], //CFURLRef item,
                                    false, //Boolean exclude,
                                    false //Boolean excludeByPath
                                    );
    
}
 */

@end
