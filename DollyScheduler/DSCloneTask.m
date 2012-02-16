/*
 *  CVMainController.m
 *  CloneVolume
 *
 *  Created by Pumptheory P/L on 12/01/11.
 *  Copyright 2011 Pumptheory P/L. All rights reserved.
 *
 */

#import <DiskArbitration/DiskArbitration.h>

#import <IOKit/pwr_mgt/IOPMLib.h>
#import "DSCloneTask.h"
#import "DSDisk.h"
#import "ADDAppConfig.h"

NSString *CVErrorDomainScheduler = @"CVErrorDomain";

//static int observingContext;


enum {
    CVUnspecifiedError	  = 1,
    CVUnableToMountError	  = 2,
    CVUnableToUnmountError  = 3,
    CVNotEnoughSpaceError	  = 4,
};

@interface DSCloneTask ()

- (BOOL)doASRCopyWithSourceDisk;
- (BOOL)doSyncWithSourceDisk;

- (void)cloneThread:(NSDictionary *)params;
- (void)finishedWithError;
- (void)updateProgress:(NSDictionary *)info;

@end

@implementation DSCloneTask


@synthesize aborted;
@synthesize paused;
@synthesize sourceDisk;
@synthesize targetDisk;
@synthesize delegate;
@synthesize incremental;
@synthesize busy;
@synthesize progress;
@synthesize state;
//@synthesize menuItem;
@synthesize error;
@synthesize lastRunDate;
@synthesize nextRunDate;
@synthesize interval;


- (id)init
{
    if ((self = [super init])) {
        lastRunDate = [[NSDate alloc] init];
        nextRunDate = [[NSDate alloc] init];
        myTask = [[NSTask alloc] init];
    }
    //[self getSettings];
    return self;
}

- (void)dealloc
{
    [lastRunDate release];
    [nextRunDate release];
    [myTask release];
    [super dealloc];
}

typedef enum {
    UnknownState = 0,
    RestoreState = 1,
    VerifyState = 2,
    UpdateDyldState = 3,
} ASRState;



- (void)Abort:(id)sender
{
    self.aborted = YES;
    
    
    @synchronized (self) {
    }
}

- (void)Continue
{
    self.paused = ![myTask resume];
    NSLog(@"Cloning resumed for %@", targetDisk.name);
}

- (void)Pause
{
    self.paused = [myTask suspend];;
    NSLog(@"Cloning paused for %@", targetDisk.name);
}

- (void)Start
{  
    
    //if (self.incremental)
    //    [self updateSettings];
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotificationWithOptions(center, CFSTR("dollyclonescheduler.start"), NULL, NULL, kCFNotificationDeliverImmediately); 
    
    [NSThread detachNewThreadSelector:@selector (startCloneThread)
                             toTarget:self
                           withObject:nil];
    
    
}


-(void)getSettings
{
    NSFileManager *filemgr = [NSFileManager defaultManager];
    NSString *filePathTarget = [NSString stringWithFormat:@"/Volumes/%@/Library/Application Support/DollyClone/%@", self.targetDisk.name, @"DollyCloneSettings-Info.plist"];
    //NSLog(@"filename = %@", filePathTarget);
    if ([filemgr fileExistsAtPath: filePathTarget] == YES)
    {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        //[df setTimeZone:[NSTimeZone systemTimeZone]];
        NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:filePathTarget];
        //NSLog(@"Last run = %@", [plistDict objectForKey:@"LastRunDate"]);
        
        NSString *lastRunDateString = [plistDict objectForKey:@"LastRunDate"]; //[df stringFromDate:self.lastRunDate];
        NSString *nextRunDateString = [df stringFromDate:self.nextRunDate];
        self.lastRunDate = [df dateFromString: lastRunDateString];
        self.nextRunDate = [df dateFromString: nextRunDateString];
        
        [plistDict release];
        [df release];
    }
}


-(void)updateSettings
{
    
    //  need to support multiple shceduled clones
    
    //update next run 
    NSFileManager *filemgr;
    
    if (self.sourceDisk != nil)  
    {
        filemgr = [NSFileManager defaultManager];
        NSString *filePathSource = [NSString stringWithFormat:@"/Volumes/%@/Library/Application Support/DollyClone/%@", self.sourceDisk.name, @"DollyCloneSettings-Info.plist"];
        NSString *filePathTarget = [NSString stringWithFormat:@"/Volumes/%@/Library/Application Support/DollyClone/%@", self.targetDisk.name, @"DollyCloneSettings-Info.plist"];
        
        //NSLog(@"source settings filename = %@", filePathSource);
        NSMutableDictionary *plistDict = nil;
        if ([filemgr fileExistsAtPath: filePathSource] == YES)
            plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:filePathSource];
        else
            plistDict = [[NSMutableDictionary alloc] init];
        
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        //NSTimeZone *gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        //[dateFormatter setTimeZone:gmt];
        [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
        NSString *lastRunDateString = [dateFormatter stringFromDate:self.lastRunDate];
        NSString *nextRunDateString = [dateFormatter stringFromDate:self.nextRunDate];
        [dateFormatter release];
        
        [plistDict setValue:self.sourceDisk.volumeUUID forKey:@"CloneSourceUUID"];
        [plistDict setValue:self.targetDisk.volumeUUID forKey:@"CloneTargetUUID"];
        [plistDict setValue:lastRunDateString forKey:@"LastRunDate"];
        [plistDict setValue:nextRunDateString forKey:@"NextRunDate"];
        [plistDict writeToFile:filePathSource atomically: YES];
        [plistDict writeToFile:filePathTarget atomically: YES];
        
        [plistDict release];
        
    }
}


- (void)writePipe:(NSString *)stringdata
{
    NSData *data = [stringdata dataUsingEncoding:NSUTF8StringEncoding];
    [[[myTask standardInput] fileHandleForWriting] writeData: data];
}

- (void)startCloneThread   
{
    self.busy = YES;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    pid_t child_pid = -1;
    OSStatus status;
    
    error = [NSError errorWithDomain:CVErrorDomainScheduler
                                code:CVUnspecifiedError
                            userInfo:nil];
    self.busy = YES;
    NSLog(@"source UUID = %@", sourceDisk.volumeUUID);
    NSLog(@"target UUID = %@", targetDisk.volumeUUID);
    
    

    BOOL isIncremental = incremental; //[[params objectForKey:@"incremental"] boolValue];
    BOOL wasMounted = [sourceDisk isMounted];
    
    if (!wasMounted) {
        
        if (![sourceDisk mountPrivately]) {
            error = [NSError errorWithDomain:CVErrorDomainScheduler
                                        code:CVUnableToMountError
                                    userInfo:
                     [NSDictionary dictionaryWithObject:NSLocalizedString
                      (@"Unable to mount the source volume.", 
                       @"Error Message")
                                                 forKey:NSLocalizedDescriptionKey]];
            goto LEAVE;
        }
    }
    
    NSString *launchPath = [[ADDAppConfig sharedAppConfig] cloneHelperPath];

   // myTask = [[NSTask alloc] init];
    NSPipe *pipe = [[[NSPipe alloc] init] autorelease];
    NSPipe *pipe2 = [[[NSPipe alloc] init] autorelease];
    
    [myTask setStandardInput:pipe2];
    [myTask setStandardOutput:pipe];
    [myTask setStandardError:pipe];
    
    NSFileHandle *readHandle = [pipe fileHandleForReading];
    int readFileDescriptor = [readHandle fileDescriptor];
    readFilePtr = fdopen(readFileDescriptor, "r");
    
    [myTask setLaunchPath:launchPath];
    
    
    [myTask launch];
    
    
    while (!aborted) {
        while (self.paused) 
        {
            [NSThread sleepForTimeInterval:2.0];;
        };
        size_t len;
        char *line = fgetln (readFilePtr, &len);
        if (!line) {
            if (ferror (readFilePtr)) {
                if (errno == EINTR)
                    continue;
                perror ("fgetln failed");
                goto LEAVE;
            }
            break;
        }
        
        NSLog (@"%.*s", (int)len, line);
        
        if (len < 5)
            continue;
        
        if (len >= 32 && !memcmp (line, "CloneVolume Helper started (pid:", 32)) {
            child_pid = (pid_t)atol (line + 32);
            break;
        }
    }
    IOPMAssertionID assertionID;
    IOReturn suspendSleepSuccess = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, 
                                                               kIOPMAssertionLevelOn, 
                                                               ((CFStringRef)@"Cloning Disk"),
                                                               &assertionID); 
    
    if (isIncremental) {
        if ([self doSyncWithSourceDisk]) {
            error = nil;
        }
    } else {
        if ([self doSyncWithSourceDisk]) {
            error = nil;
        }
    }
    
    if (suspendSleepSuccess == kIOReturnSuccess)
        IOPMAssertionRelease(assertionID);
    
LEAVE:
    
    //TODO: only if not aborted and no error
    
    // rename target volume to append (Clone)
    ;
    
    BOOL rename_ret = YES;
    
    if (!incremental)
    {
        rename_ret = [self.targetDisk renameTo:[NSString stringWithFormat:@"%@ (Clone)", [sourceDisk name]]];
    }
    

    [self performSelectorOnMainThread:@selector (finishedWithError)
                           withObject:error
                        waitUntilDone:NO];
    
    /* ASR should remount the volume at the end, but it won't always
     do that if there's some kind of failure. */
    if (wasMounted)
        [sourceDisk mount];
    else
        [sourceDisk unmount];
    
    //@synchronized (self) {
    //fclose (pipe); pipe = NULL;
    //}
    
    if (child_pid != -1) {
        int pid_status;
        while (waitpid (child_pid, &pid_status, 0) == -1 && errno == EINTR)
            ;
    }
    
    [pool release];
    self.busy = NO;
}

struct str {
    unsigned alloced, len;
    char *data;
};

static void add_char (struct str *str, char c)
{
    if (str->len == str->alloced)
        str->data = realloc (str->data, str->alloced += 1024);
    str->data[str->len++] = c;
}

static char *str_from_args (const char **args)
{
    struct str str = {
        .alloced = 1024,
        .data = malloc (1024),
    };
    char c;
    const char *p;
    
    while ((p = *args++)) {
        while ((c = *p)) {
            static const char *escape = "\r\n \\";
            static const char *replace = "rn \\";
            char *found;
            if ((found = strchr (escape, c))) {
                add_char (&str, '\\');
                c = replace[found - escape];
            }
            
            add_char (&str, c);
            ++p;
        }
        
        if (*args)
            add_char (&str, ' ');
    }
    add_char (&str, 0);
    
    return str.data;
}

- (BOOL)doSyncWithSourceDisk
{
    BOOL ret = NO;
    
    // format drive first if new clone
    if (!self.incremental)
    {
        const char *vol_name = [[targetDisk mountPoint] fileSystemRepresentation];
        const char *format_args[] = { vol_name, NULL };
        char *format_args_str = str_from_args(format_args);
        [self writePipe: [NSString stringWithFormat:@"FORMAT %s\n", format_args_str]];
        
        //wait for format to finish
        while (!aborted) {
            size_t len;
            char *line = fgetln (readFilePtr, &len);
            if (!line) {
                if (ferror (readFilePtr)) {
                    if (errno == EINTR)
                        continue;
                    perror ("fgetln failed");
                    goto LEAVE;
                }
                break;
            }
            
            NSLog (@"%.*s", (int)len, line);
            
            if (len >= 16 && !memcmp (line, "FORMAT: FINISHED", 16)) {
                free(format_args_str);
                break;
            }
        }
    }
    
    const char *args[] = { [[sourceDisk mountPoint] fileSystemRepresentation],
        [[targetDisk mountPoint] fileSystemRepresentation],
        NULL };
    
    //NSError *errorDump;
    //if (!error)
    //    error = errorDump;
    
    char *args_str = str_from_args (args);
    
    NSLog(@"sourceDisk: %@ sourceDisk mountPoint: %@ sourceDisk mountPoint fileSystemRepresentation: %s",
          sourceDisk,
          [sourceDisk mountPoint],
          [[sourceDisk mountPoint] fileSystemRepresentation] ? [[sourceDisk mountPoint] fileSystemRepresentation] : "<NULL>");
    NSLog(@"targetDisk: %@ targetDisk mountPoint: %@ targetDisk mountPoint fileSystemRepresentation: %s",
          targetDisk,
          [targetDisk mountPoint],
          [[targetDisk mountPoint] fileSystemRepresentation] ? [[targetDisk mountPoint] fileSystemRepresentation] : "<NULL>");
    NSLog(@"SYNCS args: %s", args_str);
    
    //fprintf (writeFilePtr, "SYNC %s\n", args_str);
    [self writePipe: [NSString stringWithFormat:@"SYNC %s\n", args_str]];
    
    free (args_str);
    
    while (!aborted) {
        while (self.paused) {};
        size_t len;
        char *line = fgetln (readFilePtr, &len);
        if (!line) {
            if (ferror (readFilePtr)) {
                if (errno == EINTR)
                    continue;
                perror ("fgetln failed");
                goto LEAVE;
            }
            break;
        }
        
        NSLog (@"%.*s", (int)len, line);
        
        if (len >= 29 && !memcmp (line, "CloneVolume Helper: FINISHED ", 29)) {
            int status = (int)atol (line + 29);
            if (!(ret = (status == 0))) {
                error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                            code:status 
                                        userInfo:nil];
                
                break;
            } else {
                // now bless drive to make it bootable
                if (!self.incremental)
                {
                    const char *bless_folder = [[NSString stringWithFormat:@"%@/System/Library/CoreServices", [targetDisk mountPoint]]     fileSystemRepresentation];
                    const char *bless_args[] = { bless_folder, NULL };
                    char *bless_args_str = str_from_args(bless_args);
                    [self writePipe: [NSString stringWithFormat:@"BLESS %s\n", bless_args_str]];
                }
                
                // Now we want to update the DYLD cache
                const char *dyld_args[] = { [[targetDisk mountPoint] fileSystemRepresentation], NULL };
                
                char *dyld_args_str = str_from_args(dyld_args);
                
                //fprintf(writeFilePtr, "UPDATE_DYLD %s\n", dyld_args_str);
                [self writePipe: [NSString stringWithFormat:@"UPDATE_DYLD %s\n", dyld_args_str]];
                
                NSLog(@"UPDATE_DYLD %s", dyld_args_str);
                
                free(dyld_args_str);
                
                NSDictionary *progressInfo 
                = [NSDictionary dictionaryWithObjectsAndKeys:
                   [NSNumber numberWithInt:UpdateDyldState], @"state",
                   [NSNumber numberWithDouble:1], 
                   @"progress", nil];
                
                [self performSelectorOnMainThread:@selector (updateProgress:)
                                       withObject:progressInfo
                                    waitUntilDone:NO];
                
            }
            
        } else if (len > 9 && !memcmp (line, "PROGRESS ", 9)) {
            double cloneProgress = atof (line + 9);
            
            NSDictionary *progressInfo 
            = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSNumber numberWithInt:RestoreState], @"state",
               [NSNumber numberWithDouble:cloneProgress], 
               @"progress", nil];
            
            [self performSelectorOnMainThread:@selector (updateProgress:)
                                   withObject:progressInfo
                                waitUntilDone:NO];
            
            
            
        } else if (len > 22 && !memcmp(line, "UPDATE_DYLD: FINISHED ", 22)) {
            int status = (int)atol (line + 22);
            if (!(ret = (status == 0))) {
                error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                            code:status 
                                        userInfo:nil];
            }
            
            break;
        } else {
            //size_t found = line.find("No space left");
            //char* errorText = substr(line, "No space left");
            //if(!errorText)
            /*
             NSString *lineout = [NSString stringWithUTF8String:line];
             NSString *searchText = @"No space left";
             NSRange range = [lineout rangeOfString : searchText];
             
             if (range.location != NSNotFound) {
             error = [NSError errorWithDomain:CVErrorDomain2
             code:CVNotEnoughSpaceError
             userInfo:
             [NSDictionary dictionaryWithObject:NSLocalizedString
             (@"There is not enough space on the target volume. "
             @"Please choose a different target volume or delete "
             @"some data from your source volume.",
             @"Error message")
             forKey:
             NSLocalizedDescriptionKey]];
             
             break;
             }
             NSLog(@"Unknown helper output: %s", line);
             */
        }
    } // while (!aborted)
    
    //if ([delegate respondsToSelector:@selector(cloneDidFinishSuccessfully:)])
    //    [delegate cloneDidFinishSuccessfully:self];
    
LEAVE:
    
    return ret;
}

- (BOOL)doASRCopyWithSourceDisk
{
    BOOL ret = NO;
    
    //NSError *errorDump;
    //if (!error)
    //    error = errorDump;
    
    error = [NSError errorWithDomain:CVErrorDomainScheduler
                                code:CVUnspecifiedError
                            userInfo:nil];
    
    //ASRState 
    state = UnknownState;
    uint32_t code;
    const char *p;
    BOOL tryAgain = NO;
    int fdToPreventUnmount = -1;
    
#define S(x) OSSwapBigToHostInt32(x)
    enum {
        ProgressStartCode = S('PSTT'),
        ProgressStopCode = S('PSTP'),
        ProgressInfoCode = S('PINF'),
        StatusCode = S('XSTA'),
    };
#undef S
    
    const char *source = [[sourceDisk devicePath] fileSystemRepresentation];
    const char *target = [[targetDisk devicePath] fileSystemRepresentation];  
    const char *args[] = { "restore", "--source",
        source, "--target", target, "--erase", "--noprompt",
        "--puppetstrings", NULL };
    
    char *args_str = str_from_args (args);
    
TRY_AGAIN:
    //fprintf (pipe, "LAUNCH_ASR %s\n", args_str);
    [self writePipe: [NSString stringWithFormat:@"LAUNCH_ASR %s\n", args_str]];
    
    while (!aborted) {
        while (self.paused) {};
        size_t len;
        char *line = fgetln (readFilePtr, &len);
        if (!line) {
            if (ferror (readFilePtr)) {
                if (errno == EINTR)
                    continue;
                perror ("fgetln failed");
                goto LEAVE;
            }
            break;
        }
        
        NSLog (@"%.*s", (int)len, line);
        
        if (len < 5)
            continue;
        
        if (len >= 29 && !memcmp (line, "CloneVolume Helper: FINISHED ", 
                                  29)) {
            if (tryAgain) {
                /* This is a bit of a hack.  To stop asr from unmounting the source,
                 we open a file descriptor on the volume.  This will force asr to
                 do a non-block copy and then it might fit. */
                [sourceDisk mount];
                NSString *mountPoint = [sourceDisk mountPoint];
                if (mountPoint
                    && (fdToPreventUnmount 
                        = open ([mountPoint fileSystemRepresentation], O_RDONLY))) {
                        tryAgain = NO;
                        goto TRY_AGAIN;
                    }
            }
            break;
        }
        
        if (line[4] == '\t') {
            code = *(uint32_t *)line;
            p = line + 5;
        } else if (len > 12 && !strncmp (line, "\tCopying    PINF\t", 17)) {
            // The "Copying" message doesn't have a new-line
            code = ProgressInfoCode;
            p = line + 17;
        } else {
            static const char unmountMessage[] = "Could not unmount volume \"";
            static const char notEnoughSpaceMessage[] = "Not enough space on ";
            
            if (len > sizeof (unmountMessage)
                && !strncmp (line, unmountMessage, sizeof (unmountMessage) - 1)) {
                error = [NSError errorWithDomain:CVErrorDomainScheduler
                                            code:CVUnableToUnmountError
                                        userInfo:
                         [NSDictionary dictionaryWithObject:NSLocalizedString
                          (@"The destination volume appears to be in use. Please "
                           @"quit all other applications and then try again.",
                           @"Error message")
                                                     forKey:
                          NSLocalizedDescriptionKey]];
                goto LEAVE;
            } else if (len > sizeof (notEnoughSpaceMessage)
                       && !strncmp (line, notEnoughSpaceMessage, 
                                    sizeof (notEnoughSpaceMessage) - 1)) {
                           if (fdToPreventUnmount == -1) {
                               tryAgain = YES;
                               continue;
                           }
                           error = [NSError errorWithDomain:CVErrorDomainScheduler
                                                       code:CVNotEnoughSpaceError
                                                   userInfo:
                                    [NSDictionary dictionaryWithObject:NSLocalizedString
                                     (@"There is not enough space on the target volume. "
                                      @"Please choose a different target volume or delete "
                                      @"some data from your source volume.",
                                      @"Error message")
                                                                forKey:
                                     NSLocalizedDescriptionKey]];
                           goto LEAVE;
                       }
            
            continue;
        }
        
        const char *end = line + len;
        int cloneProgress = 0, total = 0;
        
#define SCAN_MATCH_CHAR(c) ({	    \
if (p >= end || *p != c)	    \
continue;			    \
++p;			    \
})
        
#define SCAN_TAB()	  SCAN_MATCH_CHAR('\t')
#define SCAN_NL()	  SCAN_MATCH_CHAR('\n')
        
#define SCAN_INT() ({				    \
int v_ = 0;					    \
if (p >= end || *p < '0' || *p > '9')	    \
continue;					    \
do {					    \
v_ = v_ * 10 + *p - '0';			    \
} while (++p < end && *p >= '0' && *p <= '9');  \
v_;						    \
})
        
#define SCAN_MATCH(s) ({	    \
size_t len_ = strlen (s);	    \
if ((size_t)(end - p) < len_    \
|| memcmp (p, s, len_))	    \
continue;			    \
p += len_;			    \
})
        
        switch (code) {
            case ProgressStartCode:
            case ProgressInfoCode:
                // PINF\t<x>\t100\t<state>
                cloneProgress = SCAN_INT();
                SCAN_TAB();
                total = SCAN_INT();
                SCAN_TAB();
                
                if (code == ProgressStartCode)
                    SCAN_MATCH("start ");
                
                if (!strncmp (p, "restore\n", end - p)
                    || !strncmp (p, "Copy\n", end - p))
                    state = RestoreState;
                else if (!strncmp (p, "verify\n", end - p))
                    state = VerifyState;
                else
                    state = UnknownState;
                break;
            case StatusCode:
                SCAN_MATCH("finish\n");
                ret = YES;
                break;
        }
        
        NSDictionary *progressInfo 
        = [NSDictionary dictionaryWithObjectsAndKeys:
           [NSNumber numberWithInt:state], @"state",
           [NSNumber numberWithDouble:total ? (double)cloneProgress / total : -1], 
           @"progress", nil];
        
        [self performSelectorOnMainThread:@selector (updateProgress:)
                               withObject:progressInfo
                            waitUntilDone:NO];
    } // while (!aborted)
    
    if ([delegate respondsToSelector:@selector(cloneDidFinishSuccessfully:)])
        [delegate cloneDidFinishSuccessfully:self];
    
LEAVE:
    
    if (fdToPreventUnmount != -1)
        close (fdToPreventUnmount);
    
    free (args_str);
    
    return ret;
}


- (void)updateProgress:(NSDictionary *)info
{
    if (aborted)
        return;
    
    state = [[info objectForKey:@"state"] intValue];
    double taskProgress = [[info objectForKey:@"progress"] doubleValue];
    self.progress = taskProgress;
    
   // CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();
    
   // CFNotificationCenterPostNotification(center, CFSTR("dollyclonescheduler.progress"), NULL, NULL, TRUE); 
    
    
    if ([delegate respondsToSelector:@selector(updateTaskProgress:)])
        [delegate updateTaskProgress:self];
}


- (void)finishedWithError
{
    [myTask terminate];
    [myTask release];
    
    self.busy = NO;
    
    if ([delegate respondsToSelector:@selector(finishedWithError:)])
        [delegate finishedWithError:self];    
    
}


/*
 - (void)observeValueForKeyPath:(NSString *)keyPath
 ofObject:(id)object
 change:(NSDictionary *)change
 context:(void *)context
 {
 if (context != &observingContext) {
 [super observeValueForKeyPath:keyPath
 ofObject:object
 change:change
 context:context];
 return;
 }
 
 [self checkSizes];
 }
 */

- (BOOL)isTargetSizeOk
{
    BOOL ok = YES;
    
#if 0
#warning Disabled size checking
#else
    
    if (targetDisk) {
        /* The logic used here is *identical* to that used by asr (modulo
         accuracy of my reverse engineering). */
        uint64_t spaceUsed = [self.sourceDisk spaceUsed];
        uint64_t freeSpaceAfterFormatting = [targetDisk freeSpaceAfterFormatting];
        // Now look at how much is used on the source volume
        if (freeSpaceAfterFormatting < spaceUsed) {
            NSLog (@"Free space (%llu) < used (%llu)", 
                   freeSpaceAfterFormatting, spaceUsed);
            ok = NO;
        }
    }
#endif
    return ok;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    return self.busy ? NSTerminateCancel : NSTerminateNow;
}

@end
