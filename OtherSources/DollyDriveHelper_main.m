//
//  DollyDriveHelper_main.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADDAppConfig.h"
#import "ADDServerConfig.h"
#import "ADDLaunchDManagement.h"
#import "ADDKeyChainManagement.h"
#import "ADDServerRequestJSON.h"

#include <unistd.h>
#include <errno.h>

int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    // load the server config file while the uid is still the user, to resolve the home dir and username
    
    ADDServerConfig *serverConfig = [[[ADDServerConfig alloc] initFromFile] autorelease];
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    appConfig.serverConfig = serverConfig;
    
    if (!serverConfig)
    {
        printf("Could not load server config file");
        [pool drain];
        exit(1001);
    }
    
    NSString *userName = [[NSUserName() copy] autorelease];
    
    // now we need to set the real uid to 0 (not just the euid) since otherwise
    // launchctl loads the daemon into the user launchd, not the root launchd
    
    if (setuid(0) != 0)
    {
        printf("Unable to change uid to 0: %s", strerror(errno));
        [pool drain];
        exit(1005);        
    }
    
    if (![appConfig copyTunnelHelper])
    {
        printf("Could not create tunnel helper: %s", [[appConfig.error localizedDescription] UTF8String]);
        [pool drain];
        exit(1006);
        
    }
    if (![appConfig copyThrottlerHelper])
    {
        printf("Could not create throttle helper: %s", [[appConfig.error localizedDescription] UTF8String]);
        [pool drain];
        exit(1006);
        
    }
    
    if (![appConfig copyExclusionslHelper])
    {
        printf("Could not create exclusions helper: %s", [[appConfig.error localizedDescription] UTF8String]);
        [pool drain];
        exit(1008);
        
    }
    
    ADDLaunchDManagement *launchDMgmt = [[[ADDLaunchDManagement alloc] init] autorelease];
    
    // need to create the /etc/services entry before loading the launchd plist
    if (![launchDMgmt validateEtcServicesEntry])
    {
        if (launchDMgmt.error)
        {
            // there is an entry, but it is invalid
            printf("%s", [[NSString stringWithFormat:@"Invalid /etc/services entry found: %@", [launchDMgmt.error localizedDescription]] UTF8String]);
            [pool drain];
            exit(1003);
            
        }
        
        // there is no entry at all
        if (![launchDMgmt createEtcServicesEntry])
        {
            printf("%s", [[NSString stringWithFormat:@"Could not create /etc/services entry: %@", [launchDMgmt.error localizedDescription]] UTF8String]);
            [pool drain];
            exit(1004);
        }        
    }
    
    if (![launchDMgmt createOrReplaceTunnelLaunchDaemonWithServerConfig:serverConfig andUserName:userName])
    {
        printf("%s", [[NSString stringWithFormat:@"Could not create launchd entry: %@", [launchDMgmt.error localizedDescription]] UTF8String]);
        [pool drain];
        exit(1002);
    }
    
    if (![launchDMgmt createOrReplaceThrottlerLaunchDaemon])
    {
        printf("%s", [[NSString stringWithFormat:@"Could not create throttler launchd entry: %@", [launchDMgmt.error localizedDescription]] UTF8String]);
        [pool drain];
        exit(1002);
    }
    
    
    if (![launchDMgmt createOrReplaceSchedulerLaunchDaemon])
    {
        printf("%s", [[NSString stringWithFormat:@"Could not create scheduler launchd entry: %@", [launchDMgmt.error localizedDescription]] UTF8String]);
        [pool drain];
        exit(1002);
    }
     
    
    
    ADDKeyChainManagement *kc = [[[ADDKeyChainManagement alloc] init] autorelease];
    
    // by now, the correct password will have been set in the user's keychain, so we can grab it from there
    NSString *path = [NSString stringWithFormat:@"/%@", serverConfig.afpVolumeName];
    const char *passwordString = getenv("dolly_password");
    
    if (!passwordString || strlen(passwordString) == 0)
    {
        printf("%s", [@"Could not obtain Dolly Drive password from environment" UTF8String]);
        [pool drain];
        exit(1007);
    }
    
    NSString *password = [NSString stringWithFormat:@"%s", passwordString];
    
    // since we don't want to read the password to avoid a security dialog, just set/update it every time.
    // Keychain won't create duplicate entries
    [kc addOrUpdateTimeMachineKeychainEntryForServerName:ADDAFPForwardingHost
                                                    port:ADDAFPForwardingPort
                                                    path:path
                                             accountName:serverConfig.afpUsername
                                                password:password];
        
    printf("OK");
    
    [pool drain];
    exit(0);
}
