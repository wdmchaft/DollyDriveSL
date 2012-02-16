//
//  ADDDiskSizeFormatter.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 19/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// from http://stackoverflow.com/questions/572614/objc-cocoa-class-for-converting-size-to-human-readable-string

@interface ADDDiskSizeFormatter : NSNumberFormatter 
{
@private
    BOOL useBaseTenUnits;
}

/** Flag signaling whether to calculate file size in binary units (1024) or base ten units (1000).  Default is binary units. */
@property (nonatomic, readwrite, assign, getter=isUsingBaseTenUnits) BOOL useBaseTenUnits;

@end
