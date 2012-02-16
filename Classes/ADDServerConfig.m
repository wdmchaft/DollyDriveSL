//
//  ADDServerResponse.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDServerConfig.h"
#import "ADDLaunchDManagement.h"
#import "ADDAppConfig.h"

#define ADDConfigFileName @"config"
#define ADDThrottleConfigFileName @"throttleConfig.plist"
#define ADDConfigServerConfigKey @"serverConfig"

@interface ADDServerConfig (Private)

- (NSArray *)keysToSave;
+ (NSString *)filePath;

@end

@implementation ADDServerConfig

@synthesize tunnelServers;
@synthesize afpVolumeName;
@synthesize afpUsername;
@synthesize afpPassword;
@synthesize volumeUUID;
@synthesize bonjourPort;
@synthesize sparseBundleCreated;
@synthesize tunnelArgs;
@synthesize tunnelIdentity;
@synthesize quotaSize;

@synthesize excludeRootDirs;

- (NSArray *)keysToSave
{
    return [NSArray arrayWithObjects:
            ADDServerConfigTunnelServersKey,
            ADDServerConfigAFPVolumeNameKey,
            ADDServerConfigAFPUsername, // not saving afp password
            ADDServerConfigBonjourPort,
            ADDServerConfigVolumeUUID,
            ADDServerConfigTunnelArgsKey,
            ADDServerConfigTunnelIdentityKey,
            ADDServerConfigQuotaSize,
            
            ADDServerConfigExcludeRootDirs,
            
            nil];
}

+ (NSString *)filePath
{
    return [[ADDAppConfig sharedAppConfig].supportDirectory stringByAppendingPathComponent:ADDConfigFileName];
	//return @"/Users/aufflick/Library/Application Support/DollyDrive/config";
}

+ (NSString *)throttleConfigPath
{
    return [[ADDAppConfig sharedAppConfig].supportDirectory stringByAppendingPathComponent:ADDThrottleConfigFileName];
}

+ (BOOL)configFileExists
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    return [fm fileExistsAtPath:[self filePath]];
}

+ (BOOL)createThrottleConfigIfNeeded
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:[ADDServerConfig throttleConfigPath] isDirectory:&isDirectory];
    if (!exists)
    {
        NSDictionary *config = [self plistDictionaryForThrottlerConfigWithSpeed:@"512" andState:NO]; 
        return [config  writeToFile:[ADDServerConfig throttleConfigPath] atomically:YES];
    }
    return YES;     
}

+ (NSDictionary *)plistDictionaryForThrottlerConfigWithSpeed:(NSString *)speed andState:(BOOL)state
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            speed, @"speed",
            [NSNumber numberWithBool:state], @"throttleOn",
            nil];
}

- (BOOL)saveToFile
{
    BOOL writeSuccess = NO;
    ADDLaunchDManagement *launchDMgmt = [[[ADDLaunchDManagement alloc] init] autorelease];
    
    NSArray *keysToSave = [self keysToSave];
    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithCapacity:[keysToSave count]];
    for (NSString *k in keysToSave)
    {
        id value = [self valueForKey:k];
                
        if (value != nil && ![value isEqualTo:[NSNull null]])
            [config setObject:[self valueForKey:k] forKey:k];
    }
    
    [launchDMgmt unloadThrottlerLaunchDaemon];
    writeSuccess = [config  writeToFile:[[self class] filePath] atomically:YES];
    [launchDMgmt loadThrottlerLaunchDaemon];
    return writeSuccess;
}

- (id)init
{
    if ((self = [super init]))
    {
        // setup defaults
        self.excludeRootDirs = [NSNumber numberWithBool:YES];
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
            if (![config objectForKey:ADDServerConfigExcludeRootDirs])
            {
                [config setValue:[NSNumber numberWithBool:YES] forKey:ADDServerConfigExcludeRootDirs];
            }
            
            if (![config objectForKey:ADDServerConfigTunnelArgsKey])
            {
                [config setValue:@"" forKey:ADDServerConfigExcludeRootDirs];
            }
            
            if (![config objectForKey:ADDServerConfigTunnelArgsKey])
            {
                [config setValue:@"" forKey:ADDServerConfigTunnelIdentityKey];
            }            
            
            if (![config objectForKey:ADDServerConfigQuotaSize])
                [config setValue:[NSNumber numberWithDouble:0] forKey:ADDServerConfigQuotaSize];
            
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

@end
