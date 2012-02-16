//
//  ADDExclusionTreeNodeUsers.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/03/11.
//  Copyright 2011 Pumptheory Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADDExclusionTreeNodeBase.h"

@interface ADDExclusionTreeNodeUsers : ADDExclusionTreeNodeBase
{
    NSArray *users; // Array of CBIdentity objects
}

@property (retain) NSArray *users; // Array of CBIdentity objects

+ (id)usersNode;

@end
