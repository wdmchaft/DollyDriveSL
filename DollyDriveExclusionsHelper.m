//
//  DollyDriveExclusionsHelper.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 4/06/11.
//  Copyright 2011 Pumptheory Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreServices/CoreServices.h>

#include <unistd.h>
#include <errno.h>

#import "ADDExclusionsModel.h"
#import "ADDExclusionModelConnectionDelegate.h"

extern BOOL ADDExclusionsHelper_shouldKeepRunning;

int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    ADDExclusionsModel *model = [[ADDExclusionsModel alloc] init];
    
    NSConnection *theConnection;
    theConnection = [[NSConnection defaultConnection] retain];
    
    ADDExclusionModelConnectionDelegate *delegate = [[ADDExclusionModelConnectionDelegate alloc] init];
    [theConnection setDelegate:delegate];
    
    [theConnection setRootObject:model];
    if ([theConnection registerName:@"svr"] == NO)
    {
        NSLog(@"Failed to register name\n");
        [pool drain];
        exit(1);
    }
    
    ADDExclusionsHelper_shouldKeepRunning = YES;
    
    NSRunLoop *theRL = [NSRunLoop currentRunLoop];
    while (ADDExclusionsHelper_shouldKeepRunning && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        ;
    
    [model release];
    [theConnection release];
    [delegate release];

    [pool drain];
    exit(0);
}