//
//  main.m
//  DollyScheduler
//
//  Created by Angelone John on 8/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include "DiskHandler.h"

//extern BOOL ADSchedulerHelper_shouldKeepRunning;
#define HELPER

int main (int argc, const char * argv[])
{
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    DiskHandler *helper = [[DiskHandler alloc] init];
    
    // ADSchedulerHelper_shouldKeepRunning = YES;
    
    NSRunLoop *theRL = [NSRunLoop currentRunLoop];
    while ([theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        ;
    
    [helper release];
    [pool drain];
    return 0;
}




