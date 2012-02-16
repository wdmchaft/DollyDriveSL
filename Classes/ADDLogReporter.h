//
//  ADDLogReporter.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 13/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <asl.h>

@interface ADDLogReporter : NSObject {

}

- (NSString *)gatherConsoleLogViaAppleSystemLoggerFromDate:(NSDate*)date forField:(const char *)field regex:(const char *)regex;
- (NSString *)allDollyLogs;

@end
