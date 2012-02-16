//
//  ADDExclusionTreeUser.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDExclusionTreeNodeBase.h"
#import <Collaboration/Collaboration.h>

@interface ADDExclusionTreeNodeUser : ADDExclusionTreeNodeBase
{
    CBIdentity *user;
}

@property (retain) CBIdentity *user;

+ (id)userNodeWithIdentity:(CBIdentity *)theUser;
- (id)initWithIdentity:(CBIdentity *)theUser;

- (NSSet *)userDirsToHideAndExclude;

@end
