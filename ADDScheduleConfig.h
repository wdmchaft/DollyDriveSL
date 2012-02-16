//
//  ADDScheduleConfig.h
//  DollyDriveClone
//
//  Created by John Angelone on 6/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ADDScheduleConfig : NSObject {
    NSString *frequency;
    NSNumber *interval;
    BOOL schedulerActive;
    BOOL schedulerSkipTimesActive;
    BOOL schedulerShowInStatusBar;
    NSString *schedulerOffStartTime;
    NSString *schedulerOffEndTime;
    NSString *schedulerDailyStartTime;
    NSString *schedulerLastBackup;
    NSString *schedulerNextClone;
}

@property (copy) NSString *frequency;
@property (copy) NSNumber *interval;
@property (assign) BOOL schedulerActive;
@property (assign) BOOL schedulerSkipTimesActive;
@property (assign) BOOL schedulerShowInStatusBar;
@property (copy) NSString *schedulerOffStartTime;
@property (copy) NSString *schedulerOffEndTime;
@property (copy) NSString *schedulerDailyStartTime;
@property (copy) NSString *schedulerLastBackup;
@property (copy) NSString *schedulerNextClone;

+ (NSString *)filePath;
+ (BOOL)configFileExists;

- (BOOL)saveToFile;
- (id)initFromFile;
- (NSDate *)nextCloneDate;

+ (ADDScheduleConfig *)sharedScheduleConfig;

@end


#define ADDScheduleInterval @"interval"
#define ADDScheduleFrequency @"frequency"
#define ADDScheduleOn @"schedulerActive"
#define ADDScheduleSkipTimesOn @"schedulerSkipTimesActive"
#define ADDScheduleOffStartTime @"schedulerOffStartTime"
#define ADDScheduleOffEndTime @"schedulerOffEndTime"
#define ADDScheduleDailyStartTime @"schedulerDailyStartTime"
#define ADDScheduleShowInStatusBar @"schedulerShowInStatusBar"
#define ADDScheduleLastBackup @"schedulerLastBackup"
#define ADDScheduleNextClone @"schedulerNextClone"
