//
//  ADDAppConfig.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDAppConfig.h"

#include <mach-o/dyld.h>	/* _NSGetExecutablePath */
#include <limits.h>		/* PATH_MAX */
#include <libgen.h>		/* dirname */
#include <sys/types.h>
#include <sys/stat.h>

#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

#import "ADDLaunchDManagement.h"
#import "ADDKeyChainManagement.h"
#import "ADDServerRequestJSON.h"
#import "CopyHelperClass.h"

#define ADDHelperExecutableName "DollyDriveHelper"
#define ADDSupportDirectorySuffix @"DollyDrive"
#define ADDApiPortDefaultsKey @"apiPort"
#define ADDApiPortProduction 30000
#define ADDApiPortStaging 30001

static int CopyFileOverwriting(const char *sourcePath, mode_t destMode, const char *destPath);

@implementation ADDAppConfig

@synthesize supportDirectory;
@synthesize cloneSupportDirectory;
@synthesize error;
@synthesize serverConfig;
@synthesize backupInProgress;
@synthesize firstRunBackupStarted;

ADDAppConfig *_sharedAppConfig;

+ (ADDAppConfig *)sharedAppConfig
{
    return _sharedAppConfig;
}

+ (void)initialize
{
    // KVO dynamically instantiated class can cause this to be run twice, so defend
    if (!_sharedAppConfig)
    {
        _sharedAppConfig = [[self alloc] init];
    
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(
                                                            NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES
                                                            );
        if (dirs && [dirs count])
        {
            NSString *asd = [dirs objectAtIndex:0];
            if (asd)
                [_sharedAppConfig setValue:[asd stringByAppendingPathComponent:ADDSupportDirectorySuffix]
                                    forKey:@"supportDirectory"];
        }
        
        [_sharedAppConfig setValue:@"/Library/Application Support/DollyClone"
                            forKey:@"cloneSupportDirectory"]; 
        
    }
}

- (NSString *)cloneHelperPath
{
    return [self.cloneSupportDirectory stringByAppendingPathComponent:@"CloneVolume Helper"];
}

- (NSString *)cloneHelperSourcePath
{
    return [[NSBundle mainBundle] pathForResource:@"CloneVolume Helper" ofType:nil];
}

- (NSString *)schedulerPath
{
    return [self.cloneSupportDirectory stringByAppendingPathComponent:@"DollyScheduler"];
}

- (NSString *)schedulerSourcePath
{
    return [[NSBundle mainBundle] pathForResource:@"DollyScheduler" ofType:nil];
}

- (NSString *)tunnelHelperPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"DollyDriveTunnelHelper"];
}

- (NSString *)tunnelHelperSourcePath
{
    return [[NSBundle mainBundle] pathForResource:@"DollyDriveTunnelHelper" ofType:nil];
}

- (NSString *)throttleConfigPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"throttleConfig.plist"];
}

- (NSString *)throttleHelperPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"DollyDriveThrottleHelper"];
}

- (NSString *)throttleHelperSourcePath
{
    return [[NSBundle mainBundle] pathForResource:@"DollyDriveThrottleHelper" ofType:nil];
}

- (NSString *)exclusionsHelperPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"DDExclHelper"];
}

- (NSString *)exclusionsHelperSourcePath
{
    return [[NSBundle mainBundle] pathForResource:@"DDExclHelper" ofType:nil];
}

- (NSDictionary *)plistDictionaryForThrottlerConfig
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"off", @"speed",
            nil];
}

- (BOOL)runCloneHelper
{
    CopyHelperClass *helper = [[[CopyHelperClass alloc] init] autorelease];

    if (![helper helperIsRequired])
        return YES;
    
    if ([helper schedulerIsRequired]){
        ADDLaunchDManagement *addLaunchD = [[[ADDLaunchDManagement alloc] init] autorelease];
        
        [addLaunchD unloadSchedulerLaunchAgent];
    }
        

    const char *helperPath = [[[NSBundle mainBundle] 
                               pathForAuxiliaryExecutable:@"CopyCloneHelper"]
                              fileSystemRepresentation];
    AuthorizationRef auth;  
    AuthorizationCreate (NULL, NULL, 0, &auth);
    OSStatus status = AuthorizationExecuteWithPrivileges (auth, helperPath,
                                                          0, NULL, NULL);
    AuthorizationFree (auth, 0);
    
    if (status) {
        if (status == errAuthorizationCanceled) {
            [self performSelectorOnMainThread:@selector (Abort:)
                                   withObject:self
                                waitUntilDone:NO];
        }
        
        //error = [NSError errorWithDomain:NSOSStatusErrorDomain
          //                          code:status
            //                    userInfo:nil];
        
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to execute CopyCloneHelper: %s", strerror(status)]
                                         code:status 
                                     userInfo:nil];
        
        return NO;
    }
    return YES;
}
 /*
- (BOOL)runThrottleHelper
{

    const char *helperPath = [[[NSBundle mainBundle] 
                               pathForAuxiliaryExecutable:self.throttleHelperPath]
                              fileSystemRepresentation];
    AuthorizationRef auth;  
    AuthorizationCreate (NULL, NULL, 0, &auth);
    OSStatus status = AuthorizationExecuteWithPrivileges (auth, helperPath,
                                                          0, NULL, NULL);
    AuthorizationFree (auth, 0);
    
    if (status) {
        if (status == errAuthorizationCanceled) {
            [self performSelectorOnMainThread:@selector (Abort:)
                                   withObject:self
                                waitUntilDone:NO];
        }
        
        //error = [NSError errorWithDomain:NSOSStatusErrorDomain
        //                          code:status
        //                    userInfo:nil];
        
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to execute DollyDriveThrottleHelper: %s", strerror(status)]
                                         code:status 
                                     userInfo:nil];
        
        return NO;
    }
    return YES;
}
*/
- (void) writeToCloneLogFile:(NSString *)logdata
{
    NSOutputStream *oStream = [[NSOutputStream alloc] initToFileAtPath:[self pathForCloneLogFile] append:YES];
    [oStream open];
    NSData *strData = [logdata dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t * rawstring = (const uint8_t *)[logdata UTF8String];
    [oStream write:rawstring maxLength:[strData length]];
    [oStream close];
    [oStream release];
}

- (NSString *) pathForCloneLogFile
{
    NSString *folder = @"~/Library/Logs/DollyCloneScheduler.log";
    NSString *fileName = [folder stringByExpandingTildeInPath];
    return fileName; //[folder stringByAppendingPathComponent: fileName];    
}

- (BOOL)tunnelHelperMatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:self.tunnelHelperPath isDirectory:&isDirectory];
    if (!exists || isDirectory)
        return NO;
    
    if (![fm contentsEqualAtPath:self.tunnelHelperPath andPath:self.tunnelHelperSourcePath])
        return NO;
    
    error = nil;
    NSDictionary *attributes = [fm attributesOfItemAtPath:self.tunnelHelperPath error:&error];
    if (
        error ||
        [attributes filePosixPermissions] != 0555 ||
        ![[attributes fileOwnerAccountName] isEqualToString:@"root"]
        )
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)throttleHelperMatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:self.throttleHelperPath isDirectory:&isDirectory];
    if (!exists || isDirectory)
        return NO;
    
    if (![fm contentsEqualAtPath:self.throttleHelperPath andPath:self.throttleHelperSourcePath])
        return NO;
    
    error = nil;
    NSDictionary *attributes = [fm attributesOfItemAtPath:self.throttleHelperPath error:&error];
    if (
        error ||
        [attributes filePosixPermissions] != 0555 ||
        ![[attributes fileOwnerAccountName] isEqualToString:@"root"]
        )
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)exclusionsHelperMatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:self.exclusionsHelperPath isDirectory:&isDirectory];
    if (!exists || isDirectory)
        return NO;
    
    if (![fm contentsEqualAtPath:self.exclusionsHelperPath andPath:self.exclusionsHelperSourcePath])
        return NO;
    
    error = nil;
    NSDictionary *attributes = [fm attributesOfItemAtPath:self.exclusionsHelperPath error:&error];
    if (
        error ||
        [attributes filePosixPermissions] != 04555 ||
        ![[attributes fileOwnerAccountName] isEqualToString:@"root"]
        )
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)schedulerHelperMatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:self.schedulerPath isDirectory:&isDirectory];
    if (!exists || isDirectory)
        return NO;
    
    if (![fm contentsEqualAtPath:self.schedulerPath andPath:self.schedulerSourcePath])
        return NO;
    
    error = nil;
    NSDictionary *attributes = [fm attributesOfItemAtPath:self.schedulerPath error:&error];
    if (
        error ||
        [attributes filePosixPermissions] != 04555 ||
        ![[attributes fileOwnerAccountName] isEqualToString:@"root"]
        )
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)copyTunnelHelper
{
    int err = CopyFileOverwriting(
                                  [self.tunnelHelperSourcePath UTF8String], //const char *sourcePath, 
                                  0555, //mode_t destMode, 
                                  [self.tunnelHelperPath UTF8String] //const char *destPath
                                  );
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to copy tunnel helper: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }

    return YES;
}

- (BOOL)copyThrottlerHelper
{
    int err = CopyFileOverwriting(
                                  [self.throttleHelperSourcePath UTF8String], //const char *sourcePath, 
                                  0555, //mode_t destMode, 
                                  [self.throttleHelperPath UTF8String] //const char *destPath
                                  );
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to copy throttle helper: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    return YES;
}



- (BOOL)copyExclusionslHelper
{
    // copy & set setuid
    int err = CopyFileOverwriting(
                                  [self.exclusionsHelperSourcePath UTF8String], //const char *sourcePath, 
                                  04555, //mode_t destMode, 
                                  [self.exclusionsHelperPath UTF8String] //const char *destPath
                                  );
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to copy exclusions helper: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    err = chmod([self.exclusionsHelperPath UTF8String], 04555);
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to chmod exclusions helper: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
    }
    
    return YES;

}

- (BOOL)copySchedulerHelper
{
    // copy & set setuid
    int err = CopyFileOverwriting(
                                  [self.schedulerSourcePath UTF8String], //const char *sourcePath, 
                                  04555, //mode_t destMode, 
                                  [self.schedulerPath UTF8String] //const char *destPath
                                  );
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to copy scheduler: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    err = chmod([self.schedulerPath UTF8String], 04555);
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to chmod copy scheduler: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
    }
    
    
}


- (BOOL)helperIsRequired
{
    // check for plist & /etc/services entry
    ADDLaunchDManagement *addLaunchD = [[[ADDLaunchDManagement alloc] init] autorelease];
        
    if (![addLaunchD existingLaunchDPlistMatchesForServerConfig:serverConfig])
        return YES;
    
    if (![addLaunchD existingLaunchDPlistMatchesForScheduler])
        return YES;
    
    if (![addLaunchD existingLaunchDPlistMatchesForThrottler])
        return YES;
    
    if (![addLaunchD validateEtcServicesEntry])
        return YES;
    
    if (![self tunnelHelperMatches])
        return YES;
    
    if (![self throttleHelperMatches])
        return YES;
    
    if (![self exclusionsHelperMatches])
        return YES;

        
    NSString *kcPassword = [ADDKeyChainManagement passwordFromKeychain];
    NSString *enteredPassword = self.serverConfig.afpPassword;
    if (![kcPassword isEqualToString:enteredPassword])
    {
        // password doesn't match or doesn't exist, so set it in the keychain for future use and run helper
        [ADDKeyChainManagement setDollyPasswordInKeychain:self.serverConfig.afpPassword forUsername:self.serverConfig.afpUsername];
        return YES;
    }
    
    // otherwise the password matches and we've
    
    ADDKeyChainManagement *kc = [[[ADDKeyChainManagement alloc] init] autorelease];
    
    NSString *path = [NSString stringWithFormat:@"/%@", serverConfig.afpVolumeName];

    if (
        ![kc timeMachineKeychainEntryExistsForServerName:ADDAFPForwardingHost
                                                    port:ADDAFPForwardingPort
                                                    path:path
                                             accountName:serverConfig.afpUsername]
        )
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)runHelper
{
    char pathbuf[PATH_MAX + 1];
	uint32_t bufsize = sizeof(pathbuf);
    
    if (_NSGetExecutablePath( pathbuf, &bufsize) != 0)
    {
        self.error = [NSError errorWithDomain:@"Could not determine configuration helper directory"
                                         code:0
                                     userInfo:nil];
        return NO;
    }
    
    char *executableDir = dirname(pathbuf);
    
    if (!executableDir)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"Could not find configuration helper directory"
                                         code:0
                                     userInfo:nil];
        return NO;
    }
    
    AuthorizationRef authorizationRef;
    OSStatus status = AuthorizationCreate(
                                          NULL,
                                          kAuthorizationEmptyEnvironment,
                                          kAuthorizationFlagDefaults,
                                          &authorizationRef
                                          );
    
	if (status != 0)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Error creating privilage elevation for configuration helper: %s", GetMacOSStatusErrorString(status)]
                                         code:0
                                     userInfo:nil];
        return NO;
    }
    
    char toolPath[PATH_MAX + 1];
    sprintf(toolPath, "%s/%s", executableDir, ADDHelperExecutableName);
    
    // not passing any args - comes from the config file
    char *args[] = {
        NULL
    };
    
    // put the password into an env variable for the process to pickup
    if (self.serverConfig.afpPassword)
        setenv("dolly_password", [self.serverConfig.afpPassword cStringUsingEncoding:NSASCIIStringEncoding], 1);
    
    // Run the tool using the authorization reference
    FILE *taskPipe = NULL;
    status = AuthorizationExecuteWithPrivileges(
                                                authorizationRef,
                                                toolPath,
                                                kAuthorizationFlagDefaults,
                                                args,
                                                &taskPipe
                                                );
    
    if (status !=0 || !taskPipe)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"Unable to launch configuration helper"
                                         code:status
                                     userInfo:nil];
        return NO;
        
    }
    
    unsetenv("dolly_password");
    
    //TODO: of course this should loop to ensure all data is read...
    //TODO: also SIGPIPE will crash the app etc...
    char *readBuffer = calloc(sizeof(char), 1001);
    read(fileno(taskPipe), readBuffer, 1000); // buffered reads don't work well with AuthorizationExecuteWithPrivileges
    
    NSString *outputString = [NSString stringWithCString:readBuffer encoding:NSUTF8StringEncoding];
    free(readBuffer);
    
    if (![outputString isEqualToString:@"OK"])
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unexpected result from configuration helper: %@", outputString]
                                         code:1
                                     userInfo:nil];
        return NO;
    }
    
    fclose(taskPipe);
    
    self.error = nil;
    return YES;
}

- (BOOL)isFirstRun
{
    if (firstRunSet)
        return firstRun;
    
    firstRun = ![self timeMachinePlistBackupExists] || ![ADDServerConfig configFileExists];
    firstRunSet = YES;
    
    return firstRun;
}

- (NSString *)mainTimeMachinePlistBackupPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"Pre-Dolly-com.apple.TimeMachine.plist"];
}

- (NSString *)dollyDriveTimeMachinePlistBackupPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"Post-Dolly-com.apple.TimeMachine.plist"];
}

- (BOOL)timeMachinePlistBackupExists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self mainTimeMachinePlistBackupPath]];
}

- (void)backupOrigTimeMachinePlist
{
    // create dated backup in our dir and also replace Pre-Dolly-com.apple.TimeMachine.plist
        
    //TODO: remove hard coding etc.
    NSString *source = @"/Library/Preferences/com.apple.TimeMachine.plist";
    NSString *dest1 = [self mainTimeMachinePlistBackupPath];
    
    NSString *dest2Basename = [NSString stringWithFormat:@"com.apple.TimeMachine.plist %@", [NSDate date]];
    NSString *dest2 = [self.supportDirectory stringByAppendingPathComponent:dest2Basename];
    
    NSError *anError = nil;
    [[NSFileManager defaultManager] copyItemAtPath:source toPath:dest1 error:&anError];
    
    if (anError)
        NSLog(@"error backing up %@ to %@ : %@", source, dest1, anError);
    
    anError = nil;
    [[NSFileManager defaultManager] copyItemAtPath:source toPath:dest2 error:&anError];
    
    if (anError)
        NSLog(@"error backing up %@ to %@ : %@", source, dest2, anError);
    
    // start with a fresh plist if first run
    if ([self isFirstRun])
    {
        anError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:source error:&anError];
        if (anError)
            NSLog(@"error removing main TM plist for first run: %@", anError);
    }
    
}

- (void)forceTMBackupNow
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    //TODO: make more robust
    NSTask *backupdHelperTask = [[[NSTask alloc] init] autorelease];
    [backupdHelperTask setLaunchPath:@"/System/Library/CoreServices/backupd.bundle/Contents/Resources/backupd-helper"];
    [backupdHelperTask launch];
    
    self.backupInProgress = YES;
    
    [backupdHelperTask waitUntilExit];
    
    if ([backupdHelperTask terminationStatus] == 0)
        NSLog(@"Forcing TM Backup : backupd-helper succeeded.");
    else
    {
        NSLog(@"Forcing TM Backup : backupd-helper failed.");
        self.backupInProgress = NO;
    }
    
    [pool drain];
    
}

- (NSUInteger)apiPort
{
    NSNumber *port = [[NSUserDefaults standardUserDefaults] objectForKey:ADDApiPortDefaultsKey];
    
    return port ? [port unsignedIntegerValue] : ADDApiPortStaging;
}

- (BOOL)apiPortIsStaging
{
    return [self apiPort] != ADDApiPortProduction;
}

#pragma mark - cleanup

- (void)dealloc
{
    [supportDirectory release];
    
    [super dealloc];
}

@end


//TODO: AARRGGHH - copy/paste!!
static int CopyFileOverwriting(
                               const char					*sourcePath, 
                               mode_t						destMode, 
                               const char					*destPath
                               )
// Our own version of a file copy. This routine will either handle
// the copy of the tool binary or the plist file associated with
// that binary. As the function name suggests, it writes over any 
// existing file pointed to by (const char *) destPath.
{
	int			err;
	int			junk;
	int			sourceFD;
	int			destFD;
	char		buf[65536];
	
	// Pre-conditions.
	assert(sourcePath != NULL);
	assert(destPath != NULL);
	
    (void) unlink(destPath);
	
	destFD = -1;
	
	err = 0;
	sourceFD = open(sourcePath, O_RDONLY);
	if (sourceFD < 0) {
		err = errno;
	}
	
	if (err == 0) {
		destFD = open(destPath, O_CREAT | O_EXCL | O_WRONLY, destMode);
		if (destFD < 0) {
			err = errno;
		}
	}
	
	if (err == 0) {
		ssize_t	bytesReadThisTime;
		ssize_t	bytesWrittenThisTime;
		ssize_t	bytesWritten;
		
		do {
			bytesReadThisTime = read(sourceFD, buf, sizeof(buf));
			if (bytesReadThisTime < 0) {
				err = errno;
			}
			
			bytesWritten = 0;
			while ( (err == 0) && (bytesWritten < bytesReadThisTime) ) {
				bytesWrittenThisTime = write(destFD, &buf[bytesWritten], bytesReadThisTime - bytesWritten);
				if (bytesWrittenThisTime < 0) {
					err = errno;
				} else {
					bytesWritten += bytesWrittenThisTime;
				}
			}
            
		} while ( (err == 0) && (bytesReadThisTime != 0) );
	}
	
	// Clean up.
	
	if (sourceFD != -1) {
		junk = close(sourceFD);
		assert(junk == 0);
	}
	if (destFD != -1) {
		junk = close(destFD);
		assert(junk == 0);
	}
    
#ifdef DEBUG
    fprintf(stderr, "copy '%s' %#o '%s' -> %d\n", sourcePath, (int) destMode, destPath, err);
#endif
	
	return err;
}


