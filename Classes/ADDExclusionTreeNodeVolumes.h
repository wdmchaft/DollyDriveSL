//
//  ADDExclusionTreeNodeVolumes.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 12/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDExclusionTreeNodeBase.h"

@interface ADDExclusionTreeNodeVolumes : ADDExclusionTreeNodeBase
{
    NSString *title;
}

+ (id)volumesNode;
+ (BOOL)hasVolumes;

@end
