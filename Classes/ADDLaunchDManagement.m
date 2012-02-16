//
//  ADDLaunchDManagement.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDLaunchDManagement.h"

#import "ADDKeyManagement.h"
#import "ADDAppConfig.h"
#import "MGAGrepTask.h"

#include <errno.h>
#include <stdlib.h>
#include <unistd.h>

extern char **environ;

#define ADDLaunchDTunnelDaemonLabel @"com.DollyDrive.tunnel"
#define ADDLaunchDThrottlerDaemonLabel @"com.DollyDrive.throttle"
#define ADDLaunchDSchedulerDaemonLabel @"com.dolly.clone"	
#define ADDTunnelServiceName @"com-dollyd-tun"
#define ADDTunnelServicePort @"5548"

#define ADDEtcServicesPath @"/etc/services"

static int RunLaunchCtl(bool junkStdIO, const char *command, const char *plistPath);
static int CopyFileOverwriting(const char *sourcePath, mode_t destMode, const char *destPath);

@interface ADDLaunchDManagement (Private)

- (NSDictionary *)plistDictionaryForServerConfig:(ADDServerConfig *)serverConfig andUserName:(NSString *)userName;

@end

@implementation ADDLaunchDManagement

@synthesize error;

- (BOOL)validateEtcServicesEntry
{
    //TODO: perhaps we should iterate over the file here rather than grep...
        
    // check for existing entry
    MGAGrepTask *grep = [[[MGAGrepTask alloc] init] autorelease];
    
    NSString *match = [NSString stringWithFormat:@"^%@[ \t]+%@/tcp", 
                       ADDTunnelServiceName, ADDTunnelServicePort];
    
    NSArray *results = [grep egrepFile:ADDEtcServicesPath forRegex:match];
    
    if ([results count] == 1)
    {
        // exactly one match of com-dollydrive-tunnel 5548/tcp
        return YES;
    }
    else if ([results count] > 1)
    {
        // unexpected result
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"Found unexpected entry in /etc/services - please contact Dolly Drive support"
                                         code:1
                                     userInfo:nil];
        return NO;
    }
    
    // check for incorrect com-dollydrive-tunnel entries
    match = [NSString stringWithFormat:@"^%@", ADDTunnelServiceName];
    
    if ([[grep egrepFile:ADDEtcServicesPath forRegex:match] count])
    {
        // unexpected result
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"Found unexpected entry in /etc/services - please contact Dolly Drive support"
                                         code:2
                                     userInfo:nil];
        return NO;
    }
    
    // check for incorrect 5548/tcp entries
    match = [NSString stringWithFormat:@"[ \t]+%@/tcp", ADDTunnelServicePort];
    
    if ([[grep egrepFile:ADDEtcServicesPath forRegex:match] count])
    {
        // unexpected result
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"Found unexpected entry in /etc/services - please contact Dolly Drive support"
                                         code:3
                                     userInfo:nil];
        return NO;
    }
    
    // no entry - valid or not
    self.error = nil;
    return NO;
}

- (BOOL)createEtcServicesEntry
{
    NSString *dollyDriveEntry = [NSString stringWithFormat:@"%@  %@/tcp  # Online backup tunnel <http://dollydrive.com>\n",
								 ADDTunnelServiceName, ADDTunnelServicePort];
    
    // backup services file
    NSString *backupPath = [[ADDAppConfig sharedAppConfig].supportDirectory 
                            stringByAppendingPathComponent:[NSString stringWithFormat:@"etc_services_backup_%@", [NSDate date]]];
    
    [[NSFileManager defaultManager] copyItemAtPath:ADDEtcServicesPath toPath:backupPath error:NULL];
    
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:ADDEtcServicesPath];
    [fh seekToEndOfFile];
    
    // check if the last character is a newline
    [fh seekToFileOffset:[fh offsetInFile]-1];
    NSString *lastChar = [NSString stringWithCString:[[fh readDataOfLength:1] bytes] encoding:NSASCIIStringEncoding];
    [fh closeFile];
    
    fh = [NSFileHandle fileHandleForWritingAtPath:ADDEtcServicesPath];
    
    if (!fh)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"Unable to update /etc/services - please contact Dolly Drive support"
                                         code:3
                                     userInfo:nil];
        return NO;
    }
    
    [fh seekToEndOfFile];
    
    if (![lastChar isEqualToString:@"\n"])
    {
        [fh writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
    }
    
    [fh writeData:[dollyDriveEntry dataUsingEncoding:NSASCIIStringEncoding]];
    
    [fh closeFile];
    
    return YES;
}

- (NSString *)launchDPlistPath
{
    return [[@"/Library/LaunchDaemons" stringByAppendingPathComponent:ADDLaunchDTunnelDaemonLabel]
            stringByAppendingPathExtension:@"plist"];
}

- (NSString *)launchDSchedulerPlistPath
{    
    return [[@"/Library/LaunchAgents" stringByAppendingPathComponent:ADDLaunchDSchedulerDaemonLabel]
            stringByAppendingPathExtension:@"plist"];
}

- (NSString *)launchDThrottlerPlistPath
{
    return [[@"/Library/LaunchDaemons" stringByAppendingPathComponent:ADDLaunchDThrottlerDaemonLabel]
            stringByAppendingPathExtension:@"plist"];
    /*
    NSString *userName = [[NSUserName() copy] autorelease];
    NSString *file = [[[NSString stringWithFormat:@"/Users/%@/Library/LaunchAgents", userName] 
                        stringByAppendingPathComponent:ADDLaunchDThrottlerDaemonLabel] 
                        stringByAppendingPathExtension:@"plist"];

    return file;
     */
}

- (NSDictionary *)plistDictionaryForScheduler
{
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    
    NSArray *commandArgs = [NSArray arrayWithObjects:
                            appConfig.schedulerPath,
                            nil];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
            ADDLaunchDSchedulerDaemonLabel, @"Label",
             [NSNumber numberWithBool:YES] , @"RunAtLoad",
            //no need to set Program - set in args so arg0 isn't swallowed - could be set in both if you wanted
            commandArgs, @"ProgramArguments",
             [NSNumber numberWithBool:YES],  @"KeepAlive",
            nil];
}

- (NSDictionary *)plistDictionaryForThrottler
{
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    
    NSArray *commandArgs = [NSArray arrayWithObjects:
                            appConfig.throttleHelperPath,
                            appConfig.supportDirectory,
                            nil];
    
    NSArray *watchPaths = [NSArray arrayWithObjects:
                            appConfig.supportDirectory,
                            //[ADDServerConfig filePath],
                            //[ADDServerConfig throttleConfigPath],
                            nil];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
            ADDLaunchDThrottlerDaemonLabel, @"Label",
            [NSNumber numberWithBool:YES] , @"RunAtLoad",
            //no need to set Program - set in args so arg0 isn't swallowed - could be set in both if you wanted
            commandArgs, @"ProgramArguments",
            watchPaths, @"WatchPaths",
            [NSNumber numberWithBool:NO],  @"KeepAlive",
            nil];
}


- (NSDictionary *)plistDictionaryForSchedulerConfig
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"h", @"frequency",
            nil];
}



- (NSDictionary *)plistDictionaryForServerConfig:(ADDServerConfig *)serverConfig andUserName:(NSString *)userName
{
    //ADDKeyManagement *keyMgmt = [[[ADDKeyManagement alloc] init] autorelease];
    
    //TODO: when we're using the wrapper instead of ssh directly, the plist won't
    // need any of the server info.
    //NSString *server = [(NSDictionary *)[serverConfig.tunnelServers objectAtIndex:0] objectForKey:@"host"];
    //NSString *user = [(NSDictionary *)[serverConfig.tunnelServers objectAtIndex:0] objectForKey:@"user"];
    
//#warning REMOVE TEMP CODE - MarkA
    
    //server = @"127.0.0.1";
    
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
        
    NSArray *commandArgs = [NSArray arrayWithObjects:
                            appConfig.tunnelHelperPath,
                            [ADDServerConfig filePath],
                            nil];
        
    NSDictionary *inetDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                         forKey:@"Wait"];
    
    NSDictionary *listeners = [NSDictionary dictionaryWithObjectsAndKeys:
                               ADDTunnelServiceName ,
                               @"SockServiceName",
                               @"127.0.0.1",
                               @"SockNodeName",
                               nil];
    NSDictionary *sockets = [NSDictionary dictionaryWithObject:listeners forKey:@"Listeners"];
        
    return [NSDictionary dictionaryWithObjectsAndKeys:
            ADDLaunchDTunnelDaemonLabel, @"Label",
            userName, @"UserName",
            //no need to set Program - set in args so arg0 isn't swallowed - could be set in both if you wanted
            commandArgs, @"ProgramArguments",
            inetDict, @"inetdCompatibility",
            sockets, @"Sockets",
            nil];
}

- (BOOL)existingLaunchDPlistMatchesForServerConfig:(ADDServerConfig *)serverConfig;
{
    self.error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:[self launchDPlistPath]])
        return NO;
    
    NSDictionary *existingDict = [NSDictionary dictionaryWithContentsOfFile:[self launchDPlistPath]];
    
    NSString *userName = [[NSUserName() copy] autorelease];
    NSDictionary *newDict = [self plistDictionaryForServerConfig:serverConfig andUserName:userName];
    
    if (![existingDict isEqualToDictionary:newDict])
        return NO;
    
    return YES;
}

- (BOOL)existingLaunchDPlistMatchesForScheduler
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:[self launchDSchedulerPlistPath]])
        return NO;
    
    NSDictionary *existingDict = [NSDictionary dictionaryWithContentsOfFile:[self launchDSchedulerPlistPath]];
    
    NSDictionary *newDict = [self plistDictionaryForScheduler];
    
    if (![existingDict isEqualToDictionary:newDict])
        return NO;
    
    return YES;
}

- (BOOL)existingLaunchDPlistMatchesForThrottler
{
    self.error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:[self launchDThrottlerPlistPath]])
        return NO;
    
    NSDictionary *existingDict = [NSDictionary dictionaryWithContentsOfFile:[self launchDThrottlerPlistPath]];
    
    NSDictionary *newDict = [self plistDictionaryForThrottler];
    
    if (![existingDict isEqualToDictionary:newDict])
        return NO;
    
    return YES;
}

- (BOOL)unloadThrottlerLaunchDaemon
{
    NSFileManager *fm = [NSFileManager defaultManager];   
        
    NSDictionary *existingDict = [NSDictionary dictionaryWithContentsOfFile:[ADDServerConfig throttleConfigPath]];
    NSDictionary *config = [ADDServerConfig plistDictionaryForThrottlerConfigWithSpeed:[existingDict valueForKey:@"speed"] andState:NO];    
            
    //NSLog(@"existing throttle = %@", existingDict);
    //NSLog(@"temp throttle = %@", config);
    // temporarily write config to disable throttling
    [config  writeToFile:[ADDServerConfig throttleConfigPath] atomically:YES];
    
    int err = 0;
    NSString *destPath = [self launchDThrottlerPlistPath];
    if ([fm fileExistsAtPath:destPath])
    {
        err = RunLaunchCtl(0, "unload", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
    // reload with user's settings
    if (existingDict) //![fm fileExistsAtPath:[self launchDThrottlerPlistPath]])
        [existingDict  writeToFile:[ADDServerConfig throttleConfigPath] atomically:YES];
    
    return YES;
}

- (BOOL)unloadSchedulerLaunchAgent
{
    NSFileManager *fm = [NSFileManager defaultManager];   
    
    NSDictionary *existingDict = [self plistDictionaryForScheduler];

    int err = 0;
    NSString *destPath = [self launchDSchedulerPlistPath];
    if ([fm fileExistsAtPath:destPath])
    {
        err = RunLaunchCtl(0, "unload", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
        [fm removeItemAtPath:destPath error:nil];

    }
    
    return YES;
}

- (BOOL)loadSchedulerLaunchAgent
{
    NSFileManager *fm = [NSFileManager defaultManager];   
    
    NSDictionary *existingDict = [self plistDictionaryForScheduler];
    
    int err = 0;
    NSString *destPath = [self launchDSchedulerPlistPath];
    if ([fm fileExistsAtPath:destPath])
    {
        err = RunLaunchCtl(0, "load", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
    return YES;
}


- (BOOL)loadThrottlerLaunchDaemon
{
    NSFileManager *fm = [NSFileManager defaultManager];
    int err = 0;
    NSString *destPath = [self launchDThrottlerPlistPath];
    if ([fm fileExistsAtPath:destPath])
    {
        err = RunLaunchCtl(0, "load", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    return YES;
}

- (BOOL)createOrReplaceThrottlerLaunchDaemon
{
    self.error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSDictionary *launchDDaemon = [self plistDictionaryForThrottler];
    
    // save plist to a temp file
    NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.dollydrive.tempfile.XXXXXX"];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
    strcpy(tempFileNameCString, tempFileTemplateCString);
    int fileDescriptor = mkstemp(tempFileNameCString);
    
    if (fileDescriptor == -1)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to create temporary file for launchd plist: %s", strerror(errno)]
                                         code:errno 
                                     userInfo:nil];
        
        free(tempFileNameCString);
        close(fileDescriptor);
        
        return NO;
    }
    
    NSString *tempFileName = [fm stringWithFileSystemRepresentation:tempFileNameCString
                                                             length:strlen(tempFileNameCString)];    
    
    NSFileHandle *tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileDescriptor
                                                                 closeOnDealloc:NO];
    
    NSString *errorString;
    NSData *xmlData = [NSPropertyListSerialization dataFromPropertyList:launchDDaemon
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                       errorDescription:&errorString];
    
    if (!xmlData)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Error creating launchd plist data: %@", errorString]
                                         code:0
                                     userInfo:nil];
        
        [tempFileHandle release];
        close(fileDescriptor);
        
        return NO;
    }
    
    [tempFileHandle writeData:xmlData];
    
    [tempFileHandle release];
    close(fileDescriptor);
    
    NSString *destPath = [self launchDThrottlerPlistPath];
    
    // if the plist already exists, unload it
    int err = 0;
    
    if ([fm fileExistsAtPath:destPath])
    {
        err = RunLaunchCtl(0, "unload", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
        if (err != 0)
        {
            self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to unload existing LaunchDaemon plist: %s", strerror(err)]
                                             code:err 
                                         userInfo:nil];
            
            return NO;
        }
    }
    
    // copy the temp file into /Library/LaunchDaemons with the correct mode
    err = CopyFileOverwriting(tempFileNameCString, 0644, [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    
    [fm removeItemAtPath:tempFileName error:nil];
    free(tempFileNameCString);
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to create launchd plist: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    // load plist
    err = RunLaunchCtl(0, "load", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to load LaunchDaemon plist: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }    
    
    return YES;
}
    

- (BOOL)createOrReplaceTunnelLaunchDaemonWithServerConfig:(ADDServerConfig *)serverConfig andUserName:(NSString *)userName
{
    self.error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
   
    NSDictionary *launchDDaemon = [self plistDictionaryForServerConfig:serverConfig andUserName:userName];
    
    // save plist to a temp file
    NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.dollydrive.tempfile.XXXXXX"];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
    strcpy(tempFileNameCString, tempFileTemplateCString);
    int fileDescriptor = mkstemp(tempFileNameCString);
    
    if (fileDescriptor == -1)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to create temporary file for launchd plist: %s", strerror(errno)]
                                         code:errno 
                                     userInfo:nil];
        
        free(tempFileNameCString);
        close(fileDescriptor);
        
        return NO;
    }
    
    NSString *tempFileName = [fm stringWithFileSystemRepresentation:tempFileNameCString
                                                             length:strlen(tempFileNameCString)];    
    
    NSFileHandle *tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileDescriptor
                                                   closeOnDealloc:NO];
    
    NSString *errorString;
    NSData *xmlData = [NSPropertyListSerialization dataFromPropertyList:launchDDaemon
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                       errorDescription:&errorString];
    
    if (!xmlData)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Error creating launchd plist data: %@", errorString]
                                         code:0
                                     userInfo:nil];
        
        [tempFileHandle release];
        close(fileDescriptor);

        return NO;
    }
    
    [tempFileHandle writeData:xmlData];
    
    [tempFileHandle release];
    close(fileDescriptor);
    
    NSString *destPath = [self launchDPlistPath];
    
    // if the plist already exists, unload it
    int err = 0;
    
    if ([fm fileExistsAtPath:destPath])
    {
        err = RunLaunchCtl(0, "unload", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
        if (err != 0)
        {
            self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to unload existing LaunchDaemon plist: %s", strerror(err)]
                                             code:err 
                                         userInfo:nil];
            
            return NO;
        }
   }
    else
    {
    
    // copy the temp file into /Library/LaunchDaemons with the correct mode
        err = CopyFileOverwriting(tempFileNameCString, 0644, [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
    [fm removeItemAtPath:tempFileName error:nil];
    free(tempFileNameCString);

    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to create launchd plist: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    // load plist
    err = RunLaunchCtl(0, "load", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to load LaunchDaemon plist: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }    
    
    return YES;
}

- (BOOL)createOrReplaceSchedulerLaunchDaemon
{
    self.error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSDictionary *launchDDaemon = [self plistDictionaryForScheduler];
    
    // save plist to a temp file
    NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.dolly.clone.tempfile.XXXXXX"];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
    strcpy(tempFileNameCString, tempFileTemplateCString);
    int fileDescriptor = mkstemp(tempFileNameCString);
    
    if (fileDescriptor == -1)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to create temporary file for launchd plist: %s", strerror(errno)]
                                         code:errno 
                                     userInfo:nil];
        
        free(tempFileNameCString);
        close(fileDescriptor);
        
        return NO;
    }
    
    NSString *tempFileName = [fm stringWithFileSystemRepresentation:tempFileNameCString
                                                             length:strlen(tempFileNameCString)];    

    NSFileHandle *tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileDescriptor
                                                                 closeOnDealloc:NO];
    
    NSString *errorString;
    NSData *xmlData = [NSPropertyListSerialization dataFromPropertyList:launchDDaemon
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                       errorDescription:&errorString];
    

    if (!xmlData)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Error creating launchd plist data: %@", errorString]
                                         code:0
                                     userInfo:nil];
        
        [tempFileHandle release];
        close(fileDescriptor);
        
        return NO;
    }
    
    [tempFileHandle writeData:xmlData];
    
    [tempFileHandle release];
    close(fileDescriptor);
    
    NSString *destPath = [self launchDSchedulerPlistPath];
    
    // if the plist already exists, unload it
    int err = 0;
    
    if ([fm fileExistsAtPath:destPath])
    {
        /*
        err = RunLaunchCtl(0, "stop", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
        if (err != 0)
        {
            self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to stop existing LaunchDaemon plist: %s", strerror(err)]
                                             code:err 
                                         userInfo:nil];
            
            return NO;
        }
         */

        err = RunLaunchCtl(0, "unload", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
        if (err != 0)
        {
            self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to unload existing LaunchDaemon plist: %s", strerror(err)]
                                             code:err 
                                         userInfo:nil];
            
            return NO;
        }
    }
    else
    {
        
        // copy the temp file into /Library/LaunchDaemons with the correct mode
        err = CopyFileOverwriting(tempFileNameCString, 0644, [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    // copy the temp file into /Library/LaunchDaemons with the correct mode
    //err = CopyFileOverwriting(tempFileNameCString, 0644, [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    
    [fm removeItemAtPath:tempFileName error:nil];
    free(tempFileNameCString);
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to create launchd plist: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    // load plist
    err = RunLaunchCtl(0, "load", [destPath cStringUsingEncoding:NSASCIIStringEncoding]);
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to load LaunchDaemon plist: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }    
    else
    {
        //printf("Scheduler exec loaded");
    }
    
    return YES;
}


- (void)dealloc
{
    [error release];
    error = nil;
    
    [super dealloc];
}

@end

// From Apple sample BetterAuthorizationSample project
static int RunLaunchCtl(
                        bool						junkStdIO, 
                        const char					*command, 
                        const char					*plistPath
                        )
// Handles all the invocations of launchctl by doing the fork() + execve()
// for proper clean-up. Only two commands are really supported by our
// implementation; loading and unloading of a job via the plist pointed at 
// (const char *) plistPath.
{	
	int				err;
	const char *	args[5];
	pid_t			childPID;
	pid_t			waitResult;
	int				status;
	
	// Pre-conditions.
	assert(command != NULL);
	assert(plistPath != NULL);
	
    // Make sure we get sensible logging even if we never get to the waitpid.
    
    status = 0;
    
    // Set up the launchctl arguments.  We run launchctl using StartupItemContext 
	// because, in future system software, launchctl may decide on the launchd 
	// to talk to based on your Mach bootstrap namespace rather than your RUID.
    
	args[0] = "/bin/launchctl";
	args[1] = command;				// "load" or "unload"
	args[2] = "-w";
	args[3] = plistPath;			// path to plist
	args[4] = NULL;
	
    // Do the standard fork/exec dance.
    
	childPID = fork();
	switch (childPID) {
		case 0:
			// child
			err = 0;
            
            // If we've been told to junk the I/O for launchctl, open 
            // /dev/null and dup that down to stdin, stdout, and stderr.
            
			if (junkStdIO) {
				int		fd;
				int		err2;
                
				fd = open("/dev/null", O_RDWR);
				if (fd < 0) {
					err = errno;
				}
				if (err == 0) {
					if ( dup2(fd, STDIN_FILENO) < 0 ) {
						err = errno;
					}
				}
				if (err == 0) {
					if ( dup2(fd, STDOUT_FILENO) < 0 ) {
						err = errno;
					}
				}
				if (err == 0) {
					if ( dup2(fd, STDERR_FILENO) < 0 ) {
						err = errno;
					}
				}
				err2 = close(fd);
				if (err2 < 0) {
					err2 = 0;
				}
				if (err == 0) {
					err = err2;
				}
			}
			if (err == 0) {
				//err = execve(args[0], (char **) args, environ);
                execve(args[0], (char **) args, environ);
			}
            /* unused
			if (err < 0) {
				err = errno;
			}
             */
			_exit(EXIT_FAILURE);
			break;
		case -1:
			err = errno;
			break;
		default:
			err = 0;
			break;
	}
	
    // Only the parent gets here.  Wait for the child to complete and get its 
    // exit status.
	
	if (err == 0) {
		do {
			waitResult = waitpid(childPID, &status, 0);
		} while ( (waitResult == -1) && (errno == EINTR) );
        
		if (waitResult < 0) {
			err = errno;
		} else {
			assert(waitResult == childPID);
            
            if ( ! WIFEXITED(status) || (WEXITSTATUS(status) != 0) ) {
                err = EINVAL;
            }
		}
	}
    
#ifdef DEBUG
    fprintf(stderr, "launchctl -> %d %ld 0x%x\n", err, (long) childPID, status);
#endif
	
	return err;
}

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
    
//#ifdef DEBUG
    fprintf(stderr, "copy '%s' %#o '%s' -> %d\n", sourcePath, (int) destMode, destPath, err);
//#endif
	
	return err;
}

