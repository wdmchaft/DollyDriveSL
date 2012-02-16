//
//  ADDExclusionTreeNodeDesktop.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDExclusionTreeNodeFolderWithContents.h"

@interface ADDExclusionTreeNodeDesktop : ADDExclusionTreeNodeFolderWithContents
{
}

+ (id) nodeWithParent:(ADDExclusionTreeNodeBase *)parent;

@end
