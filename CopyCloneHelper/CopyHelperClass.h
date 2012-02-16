//
//  HelperClass.h
//  DollyDriveClone
//
//  Created by John Angelone on 6/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CopyHelperClass : NSObject {
    NSString *supportDirectory;
    NSError *error;
}

@property (readonly) NSString *supportDirectory;
@property (retain) NSError *error;


- (BOOL)copyHelper;
- (BOOL)helperIsRequired;
- (NSString *)copyHelperPath;
- (NSString *)copyHelperSourcePath;
- (BOOL)copyHelperMatches;


- (BOOL)copyScheduler;
- (BOOL)schedulerIsRequired;
- (NSString *)schedulerPath;
- (NSString *)schedulerSourcePath;
- (BOOL)schedulerMatches;

@end
