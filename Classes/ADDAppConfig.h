//
//  ADDAppConfig.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDServerConfig.h"

@interface ADDAppConfig : NSObject
{
    NSString *supportDirectory;
    ADDServerConfig *serverConfig;
    NSError *error;
    BOOL firstRun;
    BOOL firstRunSet;
    BOOL backupInProgress;
    BOOL firstRunBackupStarted;
}

@property (readonly) NSString *supportDirectory;
@property (readonly) NSString *cloneSupportDirectory;
@property (readonly) NSString *tunnelHelperPath;
@property (readonly) NSString *schedulerPath;
@property (readonly) NSString *tunnelHelperSourcePath;
@property (retain) NSError *error;
@property (retain) ADDServerConfig *serverConfig;
@property (assign) BOOL backupInProgress;
@property (assign) BOOL firstRunBackupStarted;

+ (ADDAppConfig *)sharedAppConfig;

- (NSString *)throttleHelperPath;
- (BOOL)tunnelHelperMatches;
- (BOOL)throttleHelperMatches;
- (BOOL)copyTunnelHelper;
- (BOOL)copyExclusionslHelper;
- (BOOL)copyThrottlerHelper;
- (BOOL)helperIsRequired;
- (BOOL)createThrottleConfigIfNeeded;
- (BOOL)runHelper;
- (BOOL)isFirstRun;
- (NSString *)dollyDriveTimeMachinePlistBackupPath;
- (NSString *)mainTimeMachinePlistBackupPath;
- (BOOL)timeMachinePlistBackupExists;
- (void)backupOrigTimeMachinePlist;
- (void)forceTMBackupNow;
- (NSUInteger)apiPort;
- (BOOL)apiPortIsStaging;
- (void)writeToCloneLogFile:(NSString *)logdata;
- (NSString *)exclusionsHelperPath;
- (BOOL)schedulerHelperMatches;

@end

// perhaps this should be a secret user preference on the off chance someone is using port 5548
#define ADDAFPForwardingHost @"localhost"
#define ADDAFPForwardingHostIP @"127.0.0.1"
#define ADDAFPForwardingPort 5548
