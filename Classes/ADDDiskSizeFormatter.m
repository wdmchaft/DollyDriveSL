//
//  ADDDiskSizeFormatter.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 19/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDDiskSizeFormatter.h"

static const char sUnits[] = { '\0', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y' };
static int sMaxUnits = sizeof sUnits - 1;

@implementation ADDDiskSizeFormatter

@synthesize useBaseTenUnits;

- (NSString *) stringFromNumber:(NSNumber *)number
{
    int multiplier = useBaseTenUnits ? 1000 : 1024;
    int exponent = 0;
    
    double bytes = [number doubleValue];
    
    while ((bytes >= multiplier) && (exponent < sMaxUnits)) {
        bytes /= multiplier;
        exponent++;
    }
    
    NSString* formatString = self.useBaseTenUnits ? @"%@ %cB" : @"%@ %ciB";
    
    return [NSString stringWithFormat:formatString, [super stringFromNumber: [NSNumber numberWithDouble: bytes]], sUnits[exponent]];
}

@end
