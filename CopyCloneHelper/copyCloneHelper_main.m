//
//  main.c
//  CopyCloneHelper
//
//  Created by John Angelone on 6/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include "CopyHelperClass.h"


int main (int argc, const char * argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    CopyHelperClass *helper = [[CopyHelperClass alloc] init];
    
    if ([helper helperIsRequired])
        ([helper copyHelper]);
    
    if ([helper schedulerIsRequired])
        ([helper copyScheduler]);
    
    [helper release];
    [pool drain];
    return 0;
}

