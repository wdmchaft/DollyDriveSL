//
//  ADDServerResponse.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//TODO: rename to savedConfig - contains more than server config now...
@interface ADDServerConfig : NSObject
{
    //TODO: needs to become an array of dictionaries since user/port may differ
    NSArray *tunnelServers;
    NSString *afpVolumeName;
    NSString *afpUsername;
    NSString *afpPassword;
    NSString *volumeUUID;
    NSNumber *bonjourPort; // what is this? seems to always be 311...
    NSNumber *sparseBundleCreated;
    NSString *tunnelArgs;
    NSString *tunnelIdentity;
    NSNumber *quotaSize;
    
    NSNumber *excludeRootDirs;
}

@property (retain) NSArray *tunnelServers;
@property (retain) NSString *afpVolumeName;
@property (retain) NSString *afpUsername;
@property (retain) NSString *afpPassword;
@property (retain) NSString *volumeUUID;
@property (retain) NSNumber *bonjourPort;
@property (retain) NSNumber *sparseBundleCreated;
@property (copy) NSString *tunnelArgs;
@property (copy) NSString *tunnelIdentity;
@property (copy) NSNumber *quotaSize;

@property (retain) NSNumber *excludeRootDirs;

+ (NSString *)filePath;
+ (NSString *)throttleConfigPath;
+ (BOOL)createThrottleConfigIfNeeded;
+ (NSDictionary *)plistDictionaryForThrottlerConfigWithSpeed:(NSString *)speed andState:(BOOL)state;
+ (BOOL)configFileExists;

- (BOOL)saveToFile;
- (id)initFromFile;

@end

#define ADDServerConfigTunnelServersKey @"tunnelServers"
#define ADDServerConfigAFPVolumeNameKey @"afpVolumeName"
#define ADDServerConfigAFPUsername @"afpUsername"
#define ADDServerConfigAFPPassword @"afpPassword"
#define ADDServerConfigVolumeUUID @"volumeUUID"
#define ADDServerConfigBonjourPort @"bonjourPort"
#define ADDServerConfigSparseBundleCreatedKey @"sparseBundleCreated"
#define ADDServerConfigTunnelArgsKey @"tunnelArgs"
#define ADDServerConfigTunnelIdentityKey @"tunnelIdentity"
#define ADDServerConfigQuotaSize @"quotaSize"

#define ADDServerConfigExcludeRootDirs @"excludeRootDirs"
