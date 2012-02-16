//
//  NSStringAdditions.m
//  DollyDriveApp
//
//  Created by Alan Rogers on 11/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSStringAdditions.h"

static const char sUnits[] = { '\0', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y' };
static int sMaxUnits = sizeof sUnits - 1;


@implementation NSString (HumanReadableFileSize)

+ (NSString *)humanReadableFileSize:(unsigned long long)theSize usingBaseTenUnits:(BOOL)baseTenUnits
{
    int multiplier = baseTenUnits ? 1000 : 1024;
    int exponent = 0;
    
    double bytes = theSize;
    
    while ((bytes >= multiplier) && (exponent < sMaxUnits))
    {
        bytes /= multiplier;
        exponent++;
    }
    
    if (exponent == 0)
        return [NSString stringWithFormat:@"%d bytes", bytes];
    
    NSString* formatString = baseTenUnits ? @"%1.2f %cB" : @"%1.2f %ciB";
    
    return [NSString stringWithFormat:formatString, bytes, sUnits[exponent]];
}

@end
