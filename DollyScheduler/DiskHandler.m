//
//  DiskHandler.m
//  DollyDriveClone
//
//  Created by Angelone John on 8/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "DiskHandler.h"
#import <DiskArbitration/DiskArbitration.h>
#import "DSDisk.h"
#import "DSCloneTask.h"
#import "ADDAppConfig.h"
#import "ADDScheduleConfig.h"



@implementation DiskHandler
@synthesize nextSystemLogUpdate;

static void diskAppearedCallback (DADiskRef disk, void *context)
{
    [(id)context diskAppeared:disk];
}

static void diskDisappearedCallback (DADiskRef disk, void *context)
{
    [(id)context diskDisappeared:disk];
}

static void diskDescriptionChangedCallback (DADiskRef disk,
                                            CFArrayRef keys,
                                            void *context)
{
    [(id)context diskPropertiesChanged:disk];
}

/* This function is called when a notification is received. */
void MyNotificationCenterCallBack(CFNotificationCenterRef center,
                                  void *observer,
                                  id name,
                                  const void *object,
                                  CFDictionaryRef userInfo)
{

    if ([name isEqualToString:@"dollyclonescheduler.on"])
    {
        [(id)observer setScheduleActive:YES];
    }
    
    if ([name isEqualToString:@"dollyclonescheduler.off"])
    {
        [(id)observer setScheduleActive:NO];
    }
}

- (void)setScheduleActive:(BOOL)statusON
{
    scheduleOn = statusON;
}


- (id)init
{
    if ((self = [super init])) {
        
        allDisks = [[NSMutableArray alloc] init];
        cloneSchedule = [[NSMutableArray alloc] init];
        diskArbSession = DASessionCreate(kCFAllocatorDefault);
        
        DARegisterDiskAppearedCallback (diskArbSession,
                                        NULL,
                                        diskAppearedCallback,
                                        self);
        
        DARegisterDiskDisappearedCallback (diskArbSession, 
                                           NULL,
                                           diskDisappearedCallback,
                                           self);
        
        DARegisterDiskDescriptionChangedCallback (diskArbSession,
                                                  NULL,
                                                  NULL,
                                                  diskDescriptionChangedCallback,
                                                  self);
        
        DASessionScheduleWithRunLoop (diskArbSession,
                                      [[NSRunLoop currentRunLoop] getCFRunLoop],
                                      kCFRunLoopDefaultMode);
        
        
        
        [NSTimer scheduledTimerWithTimeInterval:60
                                         target:self
                                       selector:@selector(cloneTimer)
                                       userInfo:nil
                                        repeats:YES];
  
        [NSTimer scheduledTimerWithTimeInterval:30
                                         target:self
                                       selector:@selector(monitorTM)
                                       userInfo:nil
                                        repeats:YES];
        
        /* Create a notification center */
        CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
        
        /* Tell notifyd to alert us when this notification
         is received. */
        if (center) {
            CFNotificationCenterAddObserver(center,
                                            self,
                                            (CFNotificationCallback)MyNotificationCenterCallBack,
                                            CFSTR("dollyclonescheduler.quit"),
                                            NULL,
                                            CFNotificationSuspensionBehaviorDeliverImmediately);
            
            CFNotificationCenterAddObserver(center,
                                            self,
                                            (CFNotificationCallback)MyNotificationCenterCallBack,
                                            CFSTR("dollyclonescheduler.on"),
                                            NULL,
                                            CFNotificationSuspensionBehaviorDeliverImmediately);
            
            CFNotificationCenterAddObserver(center,
                                            self,
                                            (CFNotificationCallback)MyNotificationCenterCallBack,
                                            CFSTR("dollyclonescheduler.off"),
                                            NULL,
                                            CFNotificationSuspensionBehaviorDeliverImmediately);
            
            CFNotificationCenterAddObserver(center,
                                            self,
                                            (CFNotificationCallback)MyNotificationCenterCallBack,
                                            CFSTR("dollyclonescheduler.statuson"),
                                            NULL,
                                            CFNotificationSuspensionBehaviorDeliverImmediately);
            
            CFNotificationCenterAddObserver(center,
                                            self,
                                            (CFNotificationCallback)MyNotificationCenterCallBack,
                                            CFSTR("dollyclonescheduler.statusoff"),
                                            NULL,
                                            CFNotificationSuspensionBehaviorDeliverImmediately);
            
        }
        

        nextSystemLogUpdate = [[NSDate alloc] init];
        [self getSettings];
        
    }
    return self;
    
}

-(void)getSettings
{
    ADDScheduleConfig *config; // = [ADDAppConfig sharedAppConfig].scheduleConfig;
    if ([ADDScheduleConfig configFileExists])
    {
        config = [[ADDScheduleConfig alloc] initFromFile];
    }
    else 
    {
        config = [[ADDScheduleConfig alloc] init];
    }
    [config autorelease];
    scheduleOn = (config.schedulerActive == 1);
}

-(void)monitorTM
{
    if ([ADDAppConfig sharedAppConfig].backupInProgress)
    {
        for (DSCloneTask *task in cloneSchedule)
        {
            if (!task.paused)
            {
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("dollyclonescheduler.paused"), NULL, NULL, TRUE); 
                [task Pause];
            }
        }   
    }
    else
    {
        for (DSCloneTask *task in cloneSchedule)
        {
            if (task.paused)
                [task Continue];
        }   
    }
}


-(void)cloneTimer
{
    BOOL updateSystemLog = NO;

    
    if (!scheduleOn)
    {
        if (updateSystemLog) NSLog(@"Scheduler off");
        return;
    }

    //check all scheduled items
    for (DSCloneTask *task in cloneSchedule)
    {

        if (task.busy) break;
        
        //read clone settings file and get source uuid
        task.sourceDisk = [self getDiskByUUID:[self getCloneSourceUUID:task.targetDisk]];
        if (task.sourceDisk != nil && task.targetDisk != nil)
        {
            task.nextRunDate = [self getNextRunDateForTask:task];
            
            if ([[NSDate date] compare:task.nextRunDate] == NSOrderedDescending) // || YES)
            {  
                // NSLog(@"Clone launched");
               // NSString *date = [[NSDate date] init];
               // NSDateFormatter *df = [[NSDateFormatter alloc] init];
                //[df setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
                //[df setTimeZone:[NSTimeZone systemTimeZone]];
                [[ADDAppConfig sharedAppConfig] writeToCloneLogFile:[NSString stringWithFormat: @"%@ - Clone started for %@\n", [[NSDate date] description], task.targetDisk.name]];
                [[ADDAppConfig sharedAppConfig] writeToCloneLogFile:[NSString stringWithFormat: @"Source UUID - %@\n", task.sourceDisk.volumeUUID]];
                [[ADDAppConfig sharedAppConfig] writeToCloneLogFile:[NSString stringWithFormat: @"Target UUID - %@\n", task.targetDisk.volumeUUID]];
                //task.lastRunDate = [[NSDate alloc] init];
                task.nextRunDate = [self getNextRunDateForTask:task];
                task.lastRunDate = [NSDate date];
                [task updateSettings];
                [task Start];
            }
            else
            {
                //NSDateFormatter *df = [[NSDateFormatter alloc] init];
                //[df setDateFormat:@"yyyy-MM-dd"];
                if (updateSystemLog) NSLog(@"Scheduler skipped, Next Run = %@",  [task.nextRunDate description]);
            }
        }
    }
}


	





- (void)diskAppeared:(DADiskRef)diskRef
{
    // hide private disks
    if (DADiskGetOptions(diskRef) & kDADiskOptionPrivate)
        return;
    
    NSDictionary *diskDescription = [(NSDictionary *)DADiskCopyDescription(diskRef) autorelease];
    
    // skip network volumes
    NSNumber *isNetwork = [diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumeNetworkKey];
    if (isNetwork && [isNetwork boolValue])
        return;
    
    // skip boot partitions - although should also be skipped by private disks above
    NSString *mediaContent = [diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaContentKey];
    if (mediaContent)
    {
        NSSet *ignoredSet = [NSSet setWithObjects:
                             @"C12A7328-F81F-11D2-BA4B-00A0C93EC93B", // EFI System partition
                             @"Apple_Boot", // pre-GUID (PPC?) Boot OSX
                             @"426F6F74-0000-11AA-AA11-00306543ECAC", // Boot OSX
                             @"52414944-0000-11AA-AA11-00306543ECAC", // Apple Raid partition
                             @"52414944-5F4F-11AA-AA11-00306543ECAC", // offline APple Raid partition
                             @"GUID_partition_scheme",
                             nil];
        if ([ignoredSet containsObject:mediaContent])
            return;
    }
    
    // skip disk images
    NSString *deviceModel = [diskDescription objectForKey:(NSString *)kDADiskDescriptionDeviceModelKey];
    
    if (deviceModel && [deviceModel isEqualToString:@"Disk Image"])
        return;
    
    // Skip CDs etc
    NSNumber *writeable = [diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaWritableKey];
    if (writeable && ![writeable boolValue])
        return;
    
    
    // valid disk, check if target and add to timer for cloning
    DSDisk *disk = [DSDisk diskWithDiskRef:diskRef];
    
    if ([disk isTargetDisk])
    {
        //NSLog(@"target UUID: %@", disk.volumeUUID);
        [allDisks addObject:disk];
        
        // check for clone settings file and get source UUID
        if ([self getCloneSourceUUID:disk] != nil)
        {
            //NSLog(@"source UUID: %@", [self getCloneSourceUUID:disk]);
            
            
            // create a clone task and add to menu
            DSCloneTask *task = [[[DSCloneTask alloc] init] autorelease];
            
            task.targetDisk = disk;
            task.incremental = YES;
            task.delegate = self; 
            [task getSettings];
            task.nextRunDate = [self getNextRunDateForTask:task];
            [task updateSettings];
            
            
            [cloneSchedule addObject:task];
            
        }
    }
    
    // valid disk, check if target and add to timer for cloning

    
}

- (void)updateTaskProgress:(DSCloneTask *)task
{
    NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    [numberFormatter setFormat:@"###.#%"];
    //NSNumber *percentDone = [NSNumber numberWithDouble:task.progress];
    
  //  NSString CFNotificationCenterGetDistributedCenter   CFNotificationCenterGetDarwinNotifyCenter
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    

    
    CFNotificationCenterPostNotification(center, CFSTR("dollyclonescheduler.progress"), NULL, NULL, TRUE); 
    
    
    //[task.menuItem setTitle:[NSString stringWithFormat: @"%@ (%@)", task.targetDisk.name, [numberFormatter stringForObjectValue:percentDone]]]; 
    
    //NSLog(@"clone state= %i", task.state);
}

- (void)diskDisappeared:(DADiskRef)diskRef
{
    //CVDisk *disk = [CVDisk diskWithDiskRef:diskRef];
    
    //[allDisks removeObject:disk];
    
    // remove scheduled clones for disk
    //[self removeScheduleItemsForDisk:disk];
}


- (DSDisk *)getDiskByUUID:(NSString *)uuid
{
    DSDisk *selectedDisk = nil;
    for (DSDisk *disk in allDisks) {
        if ([disk.volumeUUID isEqual:uuid])
        {
            selectedDisk = disk;
            break;
        }
    }
    return selectedDisk;
}


/* gets source UUID from settings file */
- (NSString *)getCloneSourceUUID:(DSDisk *)disk
{
    NSFileManager *filemgr;
    NSString *uuid = nil;
    
    if (disk != nil)  
    {
        filemgr = [NSFileManager defaultManager];
        NSString *fileName = [NSString stringWithFormat:@"/Volumes/%@/Library/Application Support/DollyClone/%@", disk.name, @"DollyCloneSettings-Info.plist"];
        //NSString *fileName = [NSString stringWithFormat:@"/Volumes/%@/Users/%@/Library/Application Support/DollyClone/%@", disk.name, NSUserName(), @"DollyCloneSettings-Info.plist"];
        //NSLog(@"filename = %@", fileName);
        if ([filemgr fileExistsAtPath: fileName] == YES)
        {
            NSDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:fileName];
            uuid = [plistData objectForKey:@"CloneSourceUUID"];
            if ([uuid isEqualToString:disk.volumeUUID])
                uuid = nil;
        }
    }
    return uuid;
}

- (void)diskPropertiesChanged:(DADiskRef)diskRef
{
    
}

// messy!! Computes next rundate for clone */
- (NSDate *)getNextRunDateForTask:(DSCloneTask *)task
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    //[df setTimeZone:[NSTimeZone systemTimeZone]];
    //[df setDateFormat:@"yyyy-MM-dd HH:mm"];
    //NSString *nextRunDate = [df stringFromDate:[NSDate date]];
    //NSLog(@"next date =%@", nextRunDate);
    NSDate *nextRunDate = task.lastRunDate; //[NSDate date];
    NSDate *currDate = [NSDate date];
    
    ADDScheduleConfig *config;
    if ([ADDScheduleConfig configFileExists])
    {
        config = [[ADDScheduleConfig alloc] initFromFile];
        NSNumber *interval = config.interval;
        [config autorelease];
        
        
        //[df setTimeZone:[NSTimeZone systemTimeZone]];
        
        [df setDateFormat:@"yyyy-MM-dd"];
        
        NSString *currDateString = [df stringFromDate:currDate];
        NSString *nextDayDateString = [df stringFromDate:[[NSDate date] dateByAddingTimeInterval:86400]];
        [df setDateFormat:@"yyyy-MM-dd HH:mm"];
        NSMutableString *skipStartTimeString = [[NSMutableString alloc] initWithFormat:@"%@ %@", currDateString, config.schedulerOffStartTime];
        NSMutableString *skipEndTimeString;
        if ([config.schedulerOffStartTime compare:config.schedulerOffEndTime] == NSOrderedAscending)
            skipEndTimeString = [[NSMutableString alloc] initWithFormat:@"%@ %@", currDateString, config.schedulerOffEndTime];
        else
            skipEndTimeString = [[NSMutableString alloc] initWithFormat:@"%@ %@", nextDayDateString, config.schedulerOffEndTime];
        
        NSDate *skipStartTime = [df dateFromString:skipStartTimeString];
        NSDate *skipEndTime = [df dateFromString:skipEndTimeString];
        
        if ([config.frequency isEqualToString:@"h"])
        {
            if ([[task.lastRunDate dateByAddingTimeInterval:(3600*[interval intValue])] compare:[NSDate date]] == NSOrderedAscending) // if last run date + interval less than curr datetime, run clone now
            {
                  nextRunDate = [NSDate date];
            }
            else
            {    
                while ([nextRunDate compare:currDate] == NSOrderedAscending)  //  next run less than curr date
                {
                    nextRunDate = [nextRunDate dateByAddingTimeInterval:(3600*[config.interval intValue])];
                    if (config.schedulerSkipTimesActive)
                    {                
                        while ([nextRunDate compare:skipStartTime] == NSOrderedDescending && [nextRunDate compare:skipEndTime] == NSOrderedAscending)
                            nextRunDate = [nextRunDate dateByAddingTimeInterval:(3600*[interval intValue])];
                    }
                }
            }
        } else if ([config.frequency isEqualToString:@"d"])
        {
            //[df setTimeZone:[NSTimeZone systemTimeZone]];
            nextRunDate = [df dateFromString:[[[NSMutableString alloc] initWithFormat:@"%@ %@", currDateString, config.schedulerDailyStartTime] autorelease]];
            while ([nextRunDate compare:currDate] == NSOrderedAscending)
            {
                 nextRunDate = [nextRunDate dateByAddingTimeInterval:86400];
            }
        }
        
        //NSLog(@"Next run = %@", [df stringFromDate:nextRunDate]);
        
        [skipStartTimeString autorelease];
        [skipEndTimeString autorelease];
        
    }
    
    [df release];
    return nextRunDate;
}

- (void)finishedWithError:(DSCloneTask *)task
{
    task.busy = NO;
    NSString *date = [[NSDate date] description];
    
    if (task.aborted)
    {
        [self finishedAlertDidEnd:nil];
        [[ADDAppConfig sharedAppConfig] writeToLogFile:[NSString stringWithFormat: @"%@ - Clone aborted by user %@\n", date, [task.error localizedDescription]]];
    } else if (task.error) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        
        [alert setMessageText:NSLocalizedString
         (@"Failed to clone volume!", @"Message Text")];
        [alert setInformativeText:
         [NSString stringWithFormat:NSLocalizedString
          (@"There was a problem cloning the volume. %@",
           @"Informative Text"),
          [task.error localizedDescription]]];
        
        
        [[ADDAppConfig sharedAppConfig] writeToCloneLogFile:[NSString stringWithFormat: @"%@ - Error cloning drive %@\n", date, [task.error localizedDescription]]];
    } else {
        NSString *date = [[NSDate date] description];
        [[ADDAppConfig sharedAppConfig] writeToCloneLogFile:[NSString stringWithFormat: @"%@ - Clone finished for %@\n", date, task.targetDisk.name]];
    
    }
    
    
    //update config file with last backup date/time
    if ([ADDScheduleConfig configFileExists])
    {
        ADDScheduleConfig *config = [[[ADDScheduleConfig alloc] initFromFile] autorelease];
        config.schedulerLastBackup = [[NSDate date] description];
        [config saveToFile];
    }
    task.lastRunDate = [NSDate date];
    task.nextRunDate = [self getNextRunDateForTask:task];
    [task updateSettings];
    
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotificationWithOptions(center, CFSTR("dollyclonescheduler.stop"), NULL, NULL, TRUE); 
    

}

@end
