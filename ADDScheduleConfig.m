//
//  ADDScheduleConfig.m
//  DollyDriveClone
//
//  Created by John Angelone on 6/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADDScheduleConfig.h"
#import "ADDAppConfig.h"

#define ADDConfigFileName @"scheduleConfig.plist"
#define ADDSupportDirectorySuffix @"DollyDrive"

@interface ADDScheduleConfig (Private)

- (NSArray *)keysToSave;
+ (NSString *)filePath;

@end

@implementation ADDScheduleConfig 

@synthesize frequency;
@synthesize interval;
@synthesize schedulerActive;
@synthesize schedulerSkipTimesActive;
@synthesize schedulerDailyStartTime;
@synthesize schedulerOffStartTime;
@synthesize schedulerOffEndTime;
@synthesize schedulerShowInStatusBar;
@synthesize schedulerLastBackup;
@synthesize schedulerNextClone;

- (NSArray *)keysToSave
{
    return [NSArray arrayWithObjects:
            ADDScheduleInterval,
            ADDScheduleFrequency,    
            ADDScheduleOn,  
            ADDScheduleSkipTimesOn,  
            ADDScheduleOffStartTime, 
            ADDScheduleOffEndTime, 
            ADDScheduleDailyStartTime, 
            ADDScheduleShowInStatusBar,
            ADDScheduleLastBackup,
            ADDScheduleNextClone,
            nil];
}

+ (NSString *)filePath
{
    //NSLog(@"settings path=%@", [[ADDAppConfig sharedAppConfig].cloneSupportDirectory stringByAppendingPathComponent:ADDConfigFileName]);
    return [[ADDAppConfig sharedAppConfig].cloneSupportDirectory stringByAppendingPathComponent:ADDConfigFileName];

}

+ (BOOL)configFileExists
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    return [fm fileExistsAtPath:[self filePath]];
}	

- (BOOL)saveToFile
{
    NSLog(@"Dolly Scheduler configuration updated");
    NSArray *keysToSave = [self keysToSave];
    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithCapacity:[keysToSave count]];
    for (NSString *k in keysToSave)
    {
        id value = [self valueForKey:k];
        
        if (value != nil && ![value isEqualTo:[NSNull null]])
            [config setObject:[self valueForKey:k] forKey:k];
    }
    
    return [config  writeToFile:[[self class] filePath] atomically:YES];
}

- (id)init
{
    if ((self = [super init]))
    {
        // setup defaults
    }
    
    return self;
}

- (id)initFromFile
{
    if ((self = [super init]))
    {
        if ([[self class] configFileExists])
        {
            NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:[[self class] filePath]];
            
            // in case old config file version set defaults
            //TODO: version config file
            if (![config objectForKey:ADDScheduleInterval])
                [config setValue:[NSNumber numberWithInt:1] forKey:ADDScheduleInterval];
            
            if (![config objectForKey:ADDScheduleFrequency])
                [config setValue:@"h" forKey:ADDScheduleFrequency];
            
            if (![config objectForKey:ADDScheduleOn])
                [config setValue:[NSNumber numberWithInt:1]  forKey:ADDScheduleOn];
            
            if (![config objectForKey:ADDScheduleShowInStatusBar])
                [config setValue:[NSNumber numberWithInt:1]  forKey:ADDScheduleShowInStatusBar];
            
            if (![config objectForKey:ADDScheduleSkipTimesOn])
                [config setValue:[NSNumber numberWithInt:1]  forKey:ADDScheduleSkipTimesOn];
            
            if (![config objectForKey:ADDScheduleOffStartTime])
                [config setValue:@"06:00" forKey:ADDScheduleOffStartTime];
            
            if (![config objectForKey:ADDScheduleOffEndTime])
                [config setValue:@"18:00" forKey:ADDScheduleOffEndTime];
            
            if (![config objectForKey:ADDScheduleDailyStartTime])
                [config setValue:@"01:00" forKey:ADDScheduleDailyStartTime];
            
            if (![config objectForKey:ADDScheduleLastBackup])
                [config setValue:@"" forKey:ADDScheduleLastBackup];
            
            if (![config objectForKey:ADDScheduleNextClone])
                [config setValue:@"" forKey:ADDScheduleNextClone];
            
            //NSLog(@"config=%@", config);
            for (NSString *k in [self keysToSave])
            {
                [self setValue:[config objectForKey:k] forKey:k];
            }
        }
        else 
        {
            [self release];
            return nil;
        }
    }
    
    return self;
}

- (NSString *)description
{
    NSString *desc = [NSString stringWithFormat:@"<%s 0x%x>", object_getClassName(self), self];
    NSArray *keysToSave = [self keysToSave];
    for (NSString *k in keysToSave)
        desc = [desc stringByAppendingFormat:@" %@: %@,", k, [self valueForKey:k]];
    
    return desc;
}

// messy!! Computes next rundate for clone */
- (NSDate *)nextCloneDate
{
    NSDate *nextClone;
    if ([[self class] configFileExists])
    {
        [self initFromFile];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd HH:mm"];
        
        NSDate *currDate = [NSDate date];
        NSString *date = self.schedulerLastBackup;
        NSDate *lastClone = [df stringFromDate:date];
        if (lastClone == nil)
            lastClone = [NSDate date];
        nextClone = lastClone;
        


        [df setDateFormat:@"yyyy-MM-dd"];
        
        NSString *currDateString = [df stringFromDate:currDate];
        NSString *nextDayDateString = [df stringFromDate:[[NSDate date] dateByAddingTimeInterval:86400]];
        [df setDateFormat:@"yyyy-MM-dd HH:mm"];
        NSMutableString *skipStartTimeString = [[NSMutableString alloc] initWithFormat:@"%@ %@", currDateString, self.schedulerOffStartTime];
        NSMutableString *skipEndTimeString;
        if ([self.schedulerOffStartTime compare:self.schedulerOffEndTime] == NSOrderedAscending)
            skipEndTimeString = [[NSMutableString alloc] initWithFormat:@"%@ %@", currDateString, self.schedulerOffEndTime];
        else
            skipEndTimeString = [[NSMutableString alloc] initWithFormat:@"%@ %@", nextDayDateString, self.schedulerOffEndTime];
        
        NSDate *skipStartTime = [df dateFromString:skipStartTimeString];
        NSDate *skipEndTime = [df dateFromString:skipEndTimeString];
        
        if ([self.frequency isEqualToString:@"h"])
        {
            if ([[lastClone dateByAddingTimeInterval:(3600*[interval intValue])] compare:[NSDate date]] == NSOrderedAscending) // if last run date + interval less than curr datetime, run clone now
            {
                nextClone = [NSDate date];
            }
            else
            {    
                nextClone = [nextClone dateByAddingTimeInterval:(-1)];
                while ([nextClone compare:currDate] == NSOrderedAscending)  //  next run less than curr date
                {
                    nextClone = [nextClone dateByAddingTimeInterval:(3600*[self.interval intValue])];
                    if (self.schedulerSkipTimesActive)
                    {                
                        while ([nextClone compare:skipStartTime] == NSOrderedDescending && [nextClone compare:skipEndTime] == NSOrderedAscending)
                            nextClone = [nextClone dateByAddingTimeInterval:(3600*[interval intValue])];
                    }
                }
            }
        } else if ([self.frequency isEqualToString:@"d"])
        {
            //[df setTimeZone:[NSTimeZone systemTimeZone]];
            nextClone = [df dateFromString:[[[NSMutableString alloc] initWithFormat:@"%@ %@", currDateString, self.schedulerDailyStartTime] autorelease]];
            while ([nextClone compare:currDate] == NSOrderedAscending)
            {
                nextClone = [nextClone dateByAddingTimeInterval:86400];
            }
        }
        
        //NSLog(@"Next run = %@", [df stringFromDate:nextRunDate]);
        
        [skipStartTimeString autorelease];
        [skipEndTimeString autorelease];
        
        [df release];
    }
    
    return nextClone;
}

@end