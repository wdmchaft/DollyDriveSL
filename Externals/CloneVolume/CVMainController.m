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

#import "CVMainController.h"
#import "CVDisk.h"

#define TABS			\
X(CVTabViewSourceTab)		\
X(CVTabViewTargetTab)	\
X(CVTabViewProgressTab)

#define X(x)	NSString *x = @#x;
TABS
#undef X

NSString *CVErrorDomain = @"CVErrorDomain";

static int observingContext;

enum {
  CVUnspecifiedError	  = 1,
  CVUnableToMountError	  = 2,
  CVUnableToUnmountError  = 3,
  CVNotEnoughSpaceError	  = 4,
};

@interface CVMainController ()

- (void)diskAppeared:(DADiskRef)diskRef;
- (void)diskDisappeared:(DADiskRef)diskRef;
- (void)diskPropertiesChanged:(DADiskRef)diskRef;
- (void)finishedAlertDidEnd:(NSAlert *)alert;
- (void)rebuildDiskListsNeeded;
- (void)rebuildDiskLists;
- (void)checkSizes;
- (BOOL)doASRCopyWithSourceDisk:(CVDisk *)sourceDisk
		     targetDisk:(CVDisk *)targetDisk
			  error:(NSError **)perror;
- (BOOL)doSyncWithSourceDisk:(CVDisk *)sourceDisk
		  targetDisk:(CVDisk *)targetDisk
		       error:(NSError **)error;
- (void)alertDidEnd:(NSAlert *)alert
         returnCode:(NSInteger)returnCode;
- (void)cloneThread:(NSDictionary *)params;
- (void)finishedWithError:(NSError *)error;
- (void)progress:(NSDictionary *)info;

@end

@implementation CVMainController

@synthesize sourceDisks, targetDisks;
@synthesize sourceCollectionView, targetCollectionView;
@synthesize aborted;
@synthesize chosenTargetDisk;
@synthesize progressWindowSize;
@synthesize delegate;
@synthesize incremental;
@synthesize busy;

- (id)init
{
  if ((self = [super init])) {
    sourceDisks = [[NSMutableArray alloc] init];
    targetDisks = [[NSMutableArray alloc] init];
    allDisks = [[NSMutableArray alloc] init];
    self.progressWindowSize = NSMakeSize (420, 154);
  }
  return self;
}

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

- (NSImage *)cautionImage
{
  IconRef iconRef;
  
  if (GetIconRef (0, 0, kAlertCautionIcon, &iconRef))
    return nil;
  
  NSImage *i = [[[NSImage alloc] initWithIconRef:iconRef] autorelease];
  
  ReleaseIconRef (iconRef);
  
  return i;
}

- (void)awakeFromNib
{
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
  
  [targetCollectionView addObserver:self
			 forKeyPath:@"selectionIndexes"
			    options:NSKeyValueObservingOptionNew
			    context:&observingContext];
}

- (CVDisk *)selectedSourceDisk
{
  NSUInteger ndx = [[sourceCollectionView selectionIndexes] firstIndex];
  
  return (ndx == NSNotFound ? nil
	  : [sourceDisks objectAtIndex:ndx]);
}

- (CVDisk *)selectedTargetDisk
{
  NSUInteger ndx = [[targetCollectionView selectionIndexes] 
		    firstIndex];
  
  return (ndx == NSNotFound ? nil
	  : [targetDisks objectAtIndex:ndx]);
}

- (BOOL)isSourceDisk:(CVDisk *)disk
{
  return ([[disk name] length]
	  && [disk mountPoint]
	  && [[disk volumeKind] isEqualToString:@"hfs"]);
}

- (BOOL)isTargetDisk:(CVDisk *)disk
{
  return ([[disk name] length]
	  && ([[disk mediaContent] isEqualToString:@"Apple_HFS"]
	      || [[disk mediaContent] isEqualToString:@"Apple_HFSX"]
	      || [[disk mediaContent] isEqualToString:
		  @"48465300-0000-11AA-AA11-00306543ECAC"]
	      || [disk mediaWhole]));
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
  
  NSLog(@"disk description: %@", diskDescription);
  
  CVDisk *disk = [CVDisk diskWithDiskRef:diskRef];
  
  [allDisks addObject:disk];
  
  [self rebuildDiskListsNeeded];  
}

- (void)diskDisappeared:(DADiskRef)diskRef
{
  CVDisk *disk = [CVDisk diskWithDiskRef:diskRef];
  
  [allDisks removeObject:disk];
  
  [self rebuildDiskListsNeeded];
}

- (void)diskPropertiesChanged:(DADiskRef)diskRef
{
  [self rebuildDiskListsNeeded];
}

- (void)rebuildDiskListsNeeded
{
  if (!rebuildPending) {
    [self performSelector:@selector (rebuildDiskLists)
	       withObject:nil
	       afterDelay:.01];
    rebuildPending = YES;
  }
}

- (void)rebuildDiskLists
{
  rebuildPending = NO;
  
  CVDisk *selectedSourceDisk = [self selectedSourceDisk];
  CVDisk *selectedTargetDisk = [self selectedTargetDisk];
  
  NSMutableArray *srcDisks = [NSMutableArray array];
  NSMutableArray *targDisks = [NSMutableArray array];
  
  NSUInteger srcNdx = NSNotFound;
  NSUInteger targNdx = NSNotFound;
  
  for (CVDisk *disk in allDisks) {
    if ([self isSourceDisk:disk]) {
      if ([selectedSourceDisk isEqual:disk])
	srcNdx = [srcDisks count];
      [srcDisks addObject:disk];
    }
    if ([self isTargetDisk:disk] && ![selectedSourceDisk isEqual:disk]) {
      if ([selectedTargetDisk isEqual:disk])
	targNdx = [targDisks count];
      [targDisks addObject:disk];
    }
    
    /* Force the collection view to get the name again (in case the disk
     has been renamed. */
    [disk willChangeValueForKey:@"name"];
    [disk didChangeValueForKey:@"name"];
  }
  
  [self setSourceDisks:srcDisks];
  [self setTargetDisks:targDisks];
  
  [sourceCollectionView setSelectionIndexes:
   (srcNdx == NSNotFound ? [NSIndexSet indexSet]
    : [NSIndexSet indexSetWithIndex:srcNdx])];
  
  if (srcNdx == NSNotFound
      && [[[tabView selectedTabViewItem] identifier] isEqualToString:
	  CVTabViewTargetTab]) {
        [tabView selectTabViewItemWithIdentifier:CVTabViewSourceTab];
      }
  
  [targetCollectionView setSelectionIndexes:
   (targNdx == NSNotFound ? [NSIndexSet indexSet]
    : [NSIndexSet indexSetWithIndex:targNdx])];
  
  [self checkSizes];
}

- (IBAction)next:(id)sender
{
  [self rebuildDiskLists];
  [tabView selectTabViewItemWithIdentifier:CVTabViewTargetTab];
}

- (IBAction)back:(id)sender
{
  [tabView selectTabViewItemWithIdentifier:CVTabViewSourceTab];  
}

- (IBAction)clone:(id)sender
{
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  
  if (self.incremental)
  {
    [alert setMessageText:
     NSLocalizedString (@"IncrementalAlertTitle",
                        @"Message Text")];
    [alert setInformativeText:
     NSLocalizedString (@"IncrementalAlertMessage", @"Informative Text")];
  }
  else
  {
    [alert setMessageText:
     NSLocalizedString (@"The destination volume will be erased.",
                        @"Message Text")];
    [alert setInformativeText:
     NSLocalizedString (@"All data on the destination volume will be lost. Do "
                        @"you wish to continue?", @"Informative Text")];
  }
  
  [alert addButtonWithTitle:NSLocalizedString (@"Continue", @"Button Title")];
  [alert addButtonWithTitle:NSLocalizedString (@"Abort", @"Button Title")];
  
  [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@""];
  [[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\x1b"];
  
  // need a ref to the chosen disc for the rename operation
  self.chosenTargetDisk = [self selectedTargetDisk];
  
  [alert beginSheetModalForWindow:mainWindow
		    modalDelegate:self
		   didEndSelector:@selector (alertDidEnd:returnCode:)
		      contextInfo:NULL];
}

- (void)alertDidEnd:(NSAlert *)alert
	 returnCode:(NSInteger)returnCode
{
  if (returnCode != NSAlertFirstButtonReturn)
    return;
  
  CVDisk *sourceDisk = [self selectedSourceDisk];
  CVDisk *targetDisk = [self selectedTargetDisk];
  
  [tabView selectTabViewItemWithIdentifier:CVTabViewProgressTab];
  
  [progressIndicator setIndeterminate:YES];
  [progressIndicator startAnimation:self];
  
  [progressTitle setStringValue:
   [NSString stringWithFormat:NSLocalizedString
    (@"Cloning %@", @"Progress Title"),
    [sourceDisk name], [targetDisk name]]];
  
  [progressStatus setStringValue:NSLocalizedString
   (@"Initialising\\U2026", @"Progress Status")];
  
  [self setAborted:NO];
  self.busy = YES;
  
  NSRect f = [mainWindow frame];
  
  origWindowSize = f.size;
  NSSize size = self.progressWindowSize;
  
  f.origin = NSMakePoint (NSMidX (f) - size.width / 2, 
			  NSMidY (f) - size.height / 2);
  f.size = size;
  
  [self.delegate windowWillResizeToProgressRect:f];
  
  [[alert window] close];
  [mainWindow setFrame:f display:YES animate:YES];
  [mainWindow setStyleMask:
   [mainWindow styleMask] & ~NSResizableWindowMask];
  
  if (incrementalCheckBox != nil)
  {
    self.incremental = [incrementalCheckBox state] == NSOnState;
  }
  
  [NSThread detachNewThreadSelector:@selector (cloneThread:)
			   toTarget:self
			 withObject:
   [NSDictionary dictionaryWithObjectsAndKeys:
    sourceDisk, @"sourceDisk",
    targetDisk, @"targetDisk",
    [NSNumber numberWithBool:self.incremental], @"incremental",
    nil]];
}

typedef enum {
  UnknownState = 0,
  RestoreState = 1,
  VerifyState = 2,
  UpdateDyldState = 3,
} ASRState;

- (void)cloneThread:(NSDictionary *)params
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  pid_t child_pid = -1;
  OSStatus status;
  NSError *error = [NSError errorWithDomain:CVErrorDomain
				       code:CVUnspecifiedError
				   userInfo:nil];
  
  CVDisk *sourceDisk = [params objectForKey:@"sourceDisk"];
  CVDisk *targetDisk = [params objectForKey:@"targetDisk"];
  BOOL isIncremental = [[params objectForKey:@"incremental"] boolValue];
  BOOL wasMounted = [sourceDisk isMounted];
  
  if (!wasMounted) {
    [progressStatus performSelectorOnMainThread:@selector (setStringValue:)
				     withObject:NSLocalizedString
     (@"Mounting\\U2026", @"Progress Status")
				  waitUntilDone:NO];
    
    if (![sourceDisk mountPrivately]) {
      error = [NSError errorWithDomain:CVErrorDomain
				  code:CVUnableToMountError
			      userInfo:
	       [NSDictionary dictionaryWithObject:NSLocalizedString
		(@"Unable to mount the source volume.", 
		 @"Error Message")
					   forKey:NSLocalizedDescriptionKey]];
      goto LEAVE;
    }
  }
  
  const char *helperPath = [[[NSBundle mainBundle] 
                             pathForAuxiliaryExecutable:@"CloneVolume Helper"]
			    fileSystemRepresentation];
  
  AuthorizationRef auth;  
  AuthorizationCreate (NULL, NULL, 0, &auth);
  
  status = AuthorizationExecuteWithPrivileges (auth, helperPath,
					       0, NULL, &pipe);
  
  AuthorizationFree (auth, 0);
  
  if (status) {
    if (status == errAuthorizationCanceled) {
      [self performSelectorOnMainThread:@selector (abort:)
			     withObject:self
			  waitUntilDone:NO];
    }
    
    error = [NSError errorWithDomain:NSOSStatusErrorDomain
				code:status
			    userInfo:nil];
    
    goto LEAVE;
  }
  
  while (!aborted) {
    size_t len;
    char *line = fgetln (pipe, &len);
    if (!line) {
      if (ferror (pipe)) {
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
  
  // if (isIncremental) {
  if ([self doSyncWithSourceDisk:sourceDisk
                      targetDisk:targetDisk
                           error:&error]) {
    error = nil;
  }
  // } else {
  //   if ([self doASRCopyWithSourceDisk:sourceDisk
  //			   targetDisk:targetDisk
  //				error:&error]) {
  //     error = nil;
  //   }
  // }
  
  if (suspendSleepSuccess == kIOReturnSuccess)
    IOPMAssertionRelease(assertionID);
  
LEAVE:
  
  //TODO: only if not aborted and no error
  
  // rename target volume to append (Clone)
  ;
  
  BOOL rename_ret = YES;
  
  if (!incremental)
  {
    rename_ret = [self.chosenTargetDisk renameTo:[NSString stringWithFormat:@"%@ (Clone)", [sourceDisk name]]];
  }
  
  if (rename_ret)
  {
    // exclude cloned target from time machine backups
    CFURLRef url = CFURLCreateWithString(NULL, (CFStringRef)[[self.chosenTargetDisk mountPoint] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], NULL);
    if (url && !CSBackupIsItemExcluded(url, NULL))
    {
      CSBackupSetItemExcluded(url, true, true);
    }
    if (url)
      CFRelease(url);
  }
  
  [self performSelectorOnMainThread:@selector (finishedWithError:)
                         withObject:error
                      waitUntilDone:NO];
  
  /* ASR should remount the volume at the end, but it won't always
   do that if there's some kind of failure. */
  if (wasMounted)
    [sourceDisk mount];
  else
    [sourceDisk unmount];
  
  @synchronized (self) {
    fclose (pipe); pipe = NULL;
  }
  
  if (child_pid != -1) {
    int pid_status;
    while (waitpid (child_pid, &pid_status, 0) == -1 && errno == EINTR)
      ;
  }
  
  [pool release];
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

- (BOOL)doSyncWithSourceDisk:(CVDisk *)sourceDisk
		  targetDisk:(CVDisk *)targetDisk
		       error:(NSError **)error
{
  BOOL ret = NO;
  
  if (!self.incremental)
  {
    const char *vol_name = [[targetDisk mountPoint] fileSystemRepresentation];
    const char *format_args[] = { vol_name, NULL };
    char *format_args_str = str_from_args(format_args);
    fprintf (pipe, "FORMAT %s\n", format_args_str);
    
    //wait for format to finish
    while (!aborted) {
      size_t len;
      char *line = fgetln (pipe, &len);
      if (!line) {
        if (ferror (pipe)) {
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
  
  NSError *errorDump;
  if (!error)
    error = &errorDump;
  
  char *args_str = str_from_args (args);
  
  NSLog(@"sourceDisk: %@ sourceDisk mountPoint: %@ sourceDisk mountPoint fileSystemRepresentation: %s",
        sourceDisk,
        [sourceDisk mountPoint],
        [[sourceDisk mountPoint] fileSystemRepresentation] ? [[sourceDisk mountPoint] fileSystemRepresentation] : "<NULL>");
  NSLog(@"targetDisk: %@ targetDisk mountPoint: %@ targetDisk mountPoint fileSystemRepresentation: %s",
        targetDisk,
        [targetDisk mountPoint],
        [[targetDisk mountPoint] fileSystemRepresentation] ? [[targetDisk mountPoint] fileSystemRepresentation] : "<NULL>");
  NSLog(@"SYNC args: %s", args_str);
  
  fprintf (pipe, "SYNC %s\n", args_str);
  
  free (args_str);
  
  while (!aborted) {
    size_t len;
    char *line = fgetln (pipe, &len);
    if (!line) {
      if (ferror (pipe)) {
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
	*error = [NSError errorWithDomain:NSPOSIXErrorDomain
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
          fprintf (pipe, "BLESS %s\n", bless_args_str);
        }
        
        // Now we want to update the DYLD cache
        const char *dyld_args[] = { [[targetDisk mountPoint] fileSystemRepresentation], NULL };
        
        char *dyld_args_str = str_from_args(dyld_args);
        
        fprintf(pipe, "UPDATE_DYLD %s\n", dyld_args_str);
        
        NSLog(@"UPDATE_DYLD %s", dyld_args_str);
        
        free(dyld_args_str);
        
        NSDictionary *progressInfo 
	= [NSDictionary dictionaryWithObjectsAndKeys:
	   [NSNumber numberWithInt:UpdateDyldState], @"state",
	   [NSNumber numberWithDouble:0], 
	   @"progress", nil];
        
        [self performSelectorOnMainThread:@selector (progress:)
                               withObject:progressInfo
                            waitUntilDone:NO];
        
      }
      
    } else if (len > 9 && !memcmp (line, "PROGRESS ", 9)) {
      double progress = atof (line + 9);
      
      NSDictionary *progressInfo 
      = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithInt:RestoreState], @"state",
         [NSNumber numberWithDouble:progress], 
         @"progress", nil];
      
      [self performSelectorOnMainThread:@selector (progress:)
			     withObject:progressInfo
			  waitUntilDone:NO];
    } else if (len > 22 && !memcmp(line, "UPDATE_DYLD: FINISHED ", 22)) {
      int status = (int)atol (line + 22);
      if (!(ret = (status == 0))) {
	*error = [NSError errorWithDomain:NSPOSIXErrorDomain
				     code:status 
				 userInfo:nil];
      }
      
      break;
    } else
      NSLog(@"Unknown helper output: %s", line);
  } // while (!aborted)
  
  if ([delegate respondsToSelector:@selector(cloneDidFinishSuccessfully)])
    [delegate cloneDidFinishSuccessfully];
  
LEAVE:
  
  return ret;
}

- (BOOL)doASRCopyWithSourceDisk:(CVDisk *)sourceDisk
		     targetDisk:(CVDisk *)targetDisk
                          error:(NSError **)error
{
  BOOL ret = NO;
  
  NSError *errorDump;
  if (!error)
    error = &errorDump;
  
  *error = [NSError errorWithDomain:CVErrorDomain
			       code:CVUnspecifiedError
			   userInfo:nil];
  
  ASRState state = UnknownState;
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
  fprintf (pipe, "LAUNCH_ASR %s\n", args_str);
  
  while (!aborted) {
    size_t len;
    char *line = fgetln (pipe, &len);
    if (!line) {
      if (ferror (pipe)) {
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
	*error = [NSError errorWithDomain:CVErrorDomain
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
                   *error = [NSError errorWithDomain:CVErrorDomain
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
    int progress = 0, total = 0;
    
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
	progress = SCAN_INT();
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
       [NSNumber numberWithDouble:total ? (double)progress / total : -1], 
       @"progress", nil];
    
    [self performSelectorOnMainThread:@selector (progress:)
			   withObject:progressInfo
			waitUntilDone:NO];
  } // while (!aborted)
  
  if ([delegate respondsToSelector:@selector(cloneDidFinishSuccessfully)])
    [delegate cloneDidFinishSuccessfully];
  
LEAVE:
  
  if (fdToPreventUnmount != -1)
    close (fdToPreventUnmount);
  
  free (args_str);
  
  return ret;
}

- (void)progress:(NSDictionary *)info
{
  if (aborted)
    return;
  
  ASRState state = [[info objectForKey:@"state"] intValue];
  double progress = [[info objectForKey:@"progress"] doubleValue];
  
  if (state == UnknownState || progress < 0)
    [progressIndicator setIndeterminate:YES];
  else if (state == UpdateDyldState)
  {
    [progressIndicator setIndeterminate:YES];
    [progressIndicator startAnimation:self];
    [progressStatus setStringValue:@"Updating dyld cache..."];
  }
  else {
    [progressIndicator setIndeterminate:NO];
    [progressIndicator setDoubleValue:progress];
    switch (state) {
      case RestoreState:
	[progressStatus setStringValue:NSLocalizedString
	 (@"Copying\\U2026", @"Progress Status")];
	break;
      case VerifyState:	
	[progressStatus setStringValue:NSLocalizedString
	 (@"Verifying\\U2026", @"Progress Status")];
	break;
      case UnknownState:
	NSAssert (NO, @"Oops!");
    }
  }
}

- (void)finishedWithError:(NSError *)error
{
  self.busy = NO;
  
  if (aborted)
    [self finishedAlertDidEnd:nil];
  else if (error) {
    [progressIndicator stopAnimation:self];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    
    [alert setMessageText:NSLocalizedString
     (@"Failed to clone volume!", @"Message Text")];
    [alert setInformativeText:
     [NSString stringWithFormat:NSLocalizedString
      (@"There was a problem cloning the volume. %@",
       @"Informative Text"),
      [error localizedDescription]]];
    
    [alert beginSheetModalForWindow:mainWindow
		      modalDelegate:self
		     didEndSelector:@selector (finishedAlertDidEnd:)
			contextInfo:NULL];
  } else {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    
    [alert setMessageText:NSLocalizedString
     (@"Your volume was successfully cloned!", @"Message Text")];
    [alert setAlertStyle:NSInformationalAlertStyle];
    
    [alert beginSheetModalForWindow:mainWindow
		      modalDelegate:self
		     didEndSelector:@selector (finishedAlertDidEnd:)
			contextInfo:NULL];
  }
}

- (void)finishedAlertDidEnd:(NSAlert *)alert
{
  [[alert window] close];
  
  [tabView selectTabViewItemWithIdentifier:CVTabViewSourceTab];
  
  NSRect f = [mainWindow frame];
  
  f.origin = NSMakePoint (NSMidX (f) - origWindowSize.width / 2, 
			  NSMidY (f) - origWindowSize.height / 2);
  f.size = origWindowSize;
  
  [self.delegate windowWillResizeToMainRect:f];
  
  [mainWindow setFrame:f display:YES animate:YES];
  [mainWindow setStyleMask:
   [mainWindow styleMask] | NSResizableWindowMask];
  
  [self.delegate windowDidResizeToMainRect:f];
}

- (IBAction)abort:(id)sender
{
  [self setAborted:YES];
  
  [progressStatus setStringValue:NSLocalizedString
   (@"Aborting\\U2026", @"Progress Status")];
  
  @synchronized (self) {
    if (pipe)
      fputs ("ABORT\n", pipe);
  }
}

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

- (void)checkSizes
{
  BOOL ok = YES;
  
#if 0
#warning Disabled size checking
#else
  CVDisk *targetDisk = [self selectedTargetDisk];
  
  if (targetDisk) {
    /* The logic used here is *identical* to that used by asr (modulo
     accuracy of my reverse engineering). */
    uint64_t spaceUsed = [[self selectedSourceDisk] spaceUsed];
    uint64_t freeSpaceAfterFormatting = [targetDisk freeSpaceAfterFormatting];
    // Now look at how much is used on the source volume
    if (freeSpaceAfterFormatting < spaceUsed) {
      NSLog (@"Free space (%llu) < used (%llu)", 
	     freeSpaceAfterFormatting, spaceUsed);
      ok = NO;
      [targetProblemTextField setStringValue:
       NSLocalizedString (@"There is not enough space on the target volume.",
			  @"Error Message")];
    }
  }
#endif
  
  [cautionImageView setHidden:ok];
  [targetProblemTextField setHidden:ok];
  [cloneButton setEnabled:ok];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  return self.busy ? NSTerminateCancel : NSTerminateNow;
}

@end
