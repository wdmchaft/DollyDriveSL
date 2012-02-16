//
//  ADDLaunchDManagement.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDServerConfig.h"

@interface ADDLaunchDManagement : NSObject
{
    NSError *error;
}

@property (retain) NSError *error;

- (BOOL)validateEtcServicesEntry;
- (BOOL)createEtcServicesEntry;
- (NSString *)launchDPlistPath;
- (NSString *)launchDThrottlerPlistPath;
- (BOOL)existingLaunchDPlistMatchesForServerConfig:(ADDServerConfig *)serverConfig;
- (BOOL)existingLaunchDPlistMatchesForScheduler;
- (BOOL)existingLaunchDPlistMatchesForThrottler;
- (BOOL)createOrReplaceTunnelLaunchDaemonWithServerConfig:(ADDServerConfig *)serverConfig andUserName:(NSString *)userName;
- (BOOL)createOrReplaceSchedulerLaunchDaemon;
- (BOOL)createOrReplaceThrottlerLaunchDaemon;
- (NSDictionary *)plistDictionaryForThrottler;
- (BOOL)unloadThrottlerLaunchDaemon;
- (BOOL)loadThrottlerLaunchDaemon;
- (BOOL)loadSchedulerLaunchAgent;
- (BOOL)unloadSchedulerLaunchAgent;


@end
