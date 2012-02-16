//
//  ADDBonjour.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 14/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ADDBonjour : NSObject
{
    NSError *error;
}

@property (retain) NSError *error;

- (BOOL)regService;

@end
