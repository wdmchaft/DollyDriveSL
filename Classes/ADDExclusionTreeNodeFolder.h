//
//  ADDExclusionTreeNodeFolder.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 10/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDExclusionTreeNodeBase.h"

@interface ADDExclusionTreeNodeFolder : ADDExclusionTreeNodeBase
{
    NSString *title;
    NSString *baseDir;
    NSString *subDir;
}

@property (copy) NSString *baseDir;
@property (copy) NSString *subDir;

+ (id)nodeWithParent:(ADDExclusionTreeNodeBase *)parent path:(NSString *)path;
- (id)initWithParent:(ADDExclusionTreeNodeBase *)parent path:(NSString *)path;

@end
