//
//  ADDAppServices.m
//  DollyDriveApp
//
//  Created by Angelone John on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADDAppServices.h"

@implementation ADDAppServices


- (id) initWithInfoDictionary: (NSDictionary*) infoDict icon: (NSImage*) image {
	if (self = [super init]) {
		infoDictionary = [infoDict retain];
		icon = [image retain];
	}
	return self;
}

// When an instance is assigned as objectValue to a NSCell, the NSCell creates a copy.
// Therefore we have to implement the NSCopying protocol
- (id)copyWithZone:(NSZone *)zone {
    ADDAppServices *copy = [[[self class] allocWithZone: zone] initWithInfoDictionary:infoDictionary icon: icon];
    return copy;
}

- (void) dealloc {
	[infoDictionary release];
	[icon release];
	[super dealloc];
}

- (NSString*) displayName {
	NSString* displayName = [infoDictionary objectForKey: @"ServiceName"];
	return displayName;
	//return [infoDictionary objectForKey: @"CFBundleExecutable"];
}

- (NSString*) details {
	return @""; //[NSString stringWithFormat: @"Version %@", [infoDictionary objectForKey: @"CFBundleShortVersionString"]];
}
- (NSImage*) icon {
	return icon;
}

@end
