//
//  ADDAppServices.h
//  DollyDriveApp
//
//  Created by Angelone John on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>


@interface ADDAppServices : NSObject <NSCopying> {
	NSDictionary* infoDictionary;
	NSImage*  icon;
}

- (id) initWithInfoDictionary: (NSDictionary*) infoDict icon: (NSImage*) image;

- (NSString*) displayName;
- (NSString*) details;
- (NSImage*) icon;

@end
