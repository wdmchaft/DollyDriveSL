//
//  NSStringAdditions.h
//  DollyDriveApp
//
//  Created by Alan Rogers on 11/03/11.
//  Copyright 2011 Cirrus Thinking LLC. All rights reserved.
//


@interface NSString (HumanReadableFileSize)

+ (NSString *)humanReadableFileSize:(unsigned long long)theSize usingBaseTenUnits:(BOOL)baseTenUnits;

@end
