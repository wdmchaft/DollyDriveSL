//
//  DiskHandler.h
//  DollyDriveClone
//
//  Created by Angelone John on 8/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSCloneTask.h"

@interface DiskHandler : NSObject <DSCloneTaskDelegate>
{
    DASessionRef diskArbSession;
    NSMutableArray *allDisks;
    NSMutableArray *cloneSchedule;
    BOOL scheduleOn;
    NSDate *nextSystemLogUpdate;
}

@property (retain) NSDate *nextSystemLogUpdate;

- (DSDisk *)getDiskByUUID:(NSString *)uuid;
- (NSString *)getCloneSourceUUID:(DSDisk *)disk;
- (NSDate *)getNextRunDateForTask:(DSCloneTask *)task;
- (void)setScheduleActive:(BOOL)statusON;
@end
