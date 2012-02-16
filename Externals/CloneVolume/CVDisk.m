/*
 *  CVDisk.m
 *  CloneVolume
 *
 *  Created by Pumptheory P/L on 12/01/11.
 *  Copyright 2011 Pumptheory P/L. All rights reserved.
 *
 */

#include <sys/mount.h>
#include <spawn.h>

#import <IOKit/IOKitKeys.h>
#import <IOKit/kext/KextManager.h>
#import <DiskArbitration/DiskArbitration.h>

#import "CVDisk.h"

@implementation CVDisk

@synthesize image, diskRef;

+ (CVDisk *)diskWithDiskRef:(DADiskRef)aDiskRef
{
  return [[[self alloc] initWithDiskRef:aDiskRef] autorelease];
}

+ (CVDisk*)diskWithMountPath:(NSString*)mountPath
{
  DASessionRef session = DASessionCreate(kCFAllocatorDefault);
  if (!session) 
  {
    NSLog(@"Cannot create DiskArbitration session...");
    return nil;
  }        
  
  struct statfs buf;
  if ((statfs([mountPath UTF8String], &buf)) == 0)
  {
    DADiskRef disk = NULL;
    
    disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, buf.f_mntfromname);
    if (!disk)
    {
      CFRelease(session);
      return nil;
    }
    
    CVDisk* cvDisk = [[[self class] alloc] initWithDiskRef:disk];
    
    CFRelease(disk);
    CFRelease(session);
    return [cvDisk autorelease];
  }
  
  CFRelease(session);
  return nil;
}

- (CVDisk *)initWithDiskRef:(DADiskRef)aDiskRef
{
  if ((self = [super init])) {
    CFRetain (aDiskRef);
    diskRef = aDiskRef;
  }
  return self;
}

- (void)dealloc
{
  CFRelease (diskRef);
  [super dealloc];
}

- (NSDictionary *)properties
{
  return [NSMakeCollectable (DADiskCopyDescription (diskRef))
	  autorelease];
}

- (id)copy
{
  return [self retain];
}

- (NSUInteger)hash
{
  return CFHash (diskRef);
}

- (BOOL)isEqual:(id)object
{
  return ([object isKindOfClass:[CVDisk class]]
	  && ([self isKindOfClass:[object class]]
	      ? CFEqual (diskRef, [object diskRef])
	      : [object isEqual:self]));
}

#define PROP(x) ((NSString *)kDADiskDescription ## x ## Key)

- (NSString *)name
{
  /* TODO: We might want to do something if the volume is
   unmounted. */
  return [[self properties] objectForKey:PROP(VolumeName)];
}

//jaa
- (NSString *)volumeUUID
{
  CFStringRef uuidStringRef =  CFUUIDCreateString(NULL, (CFUUIDRef)[[self properties] objectForKey:PROP(VolumeUUID)]);
  return [(NSString *)uuidStringRef autorelease];
}

- (BOOL)isSourceDisk
{
  return ([self.name length]
          && [self mountPoint]
          && [[self volumeKind] isEqualToString:@"hfs"]);
}

- (BOOL)isTargetDisk
{
  return ([self.name length]
          && ([[self mediaContent] isEqualToString:@"Apple_HFS"]
              || [[self mediaContent] isEqualToString:@"Apple_HFSX"]
              || [[self mediaContent] isEqualToString:
                  @"48465300-0000-11AA-AA11-00306543ECAC"]
              || [self mediaWhole]));
}


- (uint64_t)mediaSize
{
  return [[[self properties] objectForKey:PROP(MediaSize)] 
	  unsignedLongLongValue];
}

- (NSString *)volumeKind
{
  return [[self properties] objectForKey:PROP(VolumeKind)];
}

- (NSString *)mediaContent
{
  return [[self properties] objectForKey:PROP(MediaContent)];
}

- (BOOL)mediaWhole
{
  return [[[self properties] objectForKey:PROP(MediaWhole)] boolValue];
}

- (NSImage *)image
{
  NSDictionary *d = [[self properties] objectForKey:PROP(MediaIcon)];
  
  NSString *bundleKey = (NSString *)kCFBundleIdentifierKey;
  
  NSString *bundleName = [d objectForKey:bundleKey];
  NSString *resource = [d objectForKey:@kIOBundleResourceFileKey];
  
  NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleName];
  
  if (!bundle) {
    NSURL *bundleURL = [NSMakeCollectable
                        (KextManagerCreateURLForBundleIdentifier (kCFAllocatorDefault,
                                                                  (CFStringRef)bundleName))
			autorelease];
    if (!bundleURL) {
      // TODO: Use a default image
      
    } else {
      bundle = [NSBundle bundleWithPath:[bundleURL path]];
    }
  }
  
  NSString *iconPath = [bundle pathForResource:resource ofType:nil];
  
  return [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
}

- (NSString *)bsdName
{
  const char *bsdName = DADiskGetBSDName (diskRef);
  return bsdName ? [NSString stringWithUTF8String:bsdName] : nil;
}

- (NSString *)devicePath
{
  return [@"/dev/" stringByAppendingString:[self bsdName]];
}

typedef enum {
  Waiting,
  Succeeded,
  Failed
} CVDiskCallbackState;

struct mount_context {
  NSCondition *condition;
  CVDiskCallbackState state;
};

struct rename_context {
  NSCondition *condition;
  CVDiskCallbackState state;
};

void mountCallback(DADiskRef disk, 
		   DADissenterRef dissenter,
		   void *context)
{
  struct mount_context *ctx = context;
  
  [ctx->condition lock];
  ctx->state = dissenter ? Failed : Succeeded;
  [ctx->condition unlock];
  [ctx->condition broadcast];
}

- (NSString *)mountPoint
{
  struct statfs *mntinfo;
  
  int count = getmntinfo (&mntinfo, MNT_NOWAIT);
  if (!count) {
    NSLog (@"getmntinfo failed: %s", strerror (errno));
    return NO;
  }
  
  const char *bsdName = DADiskGetBSDName (diskRef);
  if (!bsdName)
    return nil;
  
  for (int i = 0; i < count; ++i) {
    if ((!strncmp (mntinfo[i].f_mntfromname, "/dev/", 5)
	 && !strcmp (mntinfo[i].f_mntfromname + 5, bsdName))
	|| (!strncmp (mntinfo[i].f_mntfromname, "/dev/r", 6)
	    && !strcmp (mntinfo[i].f_mntfromname + 6, bsdName))) {
          return [NSString stringWithUTF8String:mntinfo[i].f_mntonname];
        }
  }
  
  return nil;
}

- (BOOL)isMounted
{
  return !![self mountPoint];
}

/* NOTE: This won't work if it's called on the thread that disk arbitration
 is scheduled on. */
- (BOOL)mountPrivately
{
  char tempDir[] = "/tmp/CloneVolume.XXXXXXXX";
  if (!mkdtemp (tempDir))
    return NO;
  
  struct mount_context ctx = {
    .condition = [[[NSCondition alloc] init] autorelease],
    .state = Waiting
  };
  
  /* NOTE: There's a leak in the Disk Arbitration framework here that comes
   from the URL we pass in. */
  DADiskMountWithArguments (diskRef,
			    (CFURLRef)[NSURL fileURLWithPath:
				       [NSString stringWithUTF8String:tempDir]],
			    0,
			    mountCallback,
			    &ctx,
			    (CFStringRef[]){ CFSTR ("nobrowse"),
			      CFSTR ("ro"), NULL });
  
  [ctx.condition lock];
  while (ctx.state == Waiting)
    [ctx.condition wait];
  [ctx.condition unlock];
  
  return ctx.state == Succeeded;
}

void disk_rename_callback(DADiskRef disk,
                          DADissenterRef dissenter,
                          void *context)
{
  struct rename_context *ctx = context;
  [ctx->condition lock];
  ctx->state = dissenter ? Failed : Succeeded;
  [ctx->condition unlock];
  [ctx->condition broadcast];
}

- (BOOL)renameTo:(NSString *)newName
{
  struct rename_context ctx = {
    .condition = [[[NSCondition alloc] init] autorelease],
    .state = Waiting
  };
  
  DADiskRename(diskRef, (CFStringRef)newName, kDADiskRenameOptionDefault, disk_rename_callback, &ctx);
  
  [ctx.condition lock];
  while (ctx.state == Waiting)
    [ctx.condition wait];
  [ctx.condition unlock];
  
  return ctx.state == Succeeded;
}

- (BOOL)mount
{
  struct mount_context ctx = {
    .condition = [[[NSCondition alloc] init] autorelease],
    .state = Waiting
  };
  
  DADiskMount (diskRef, NULL, 0, mountCallback, &ctx);
  
  [ctx.condition lock];
  while (ctx.state == Waiting)
    [ctx.condition wait];
  [ctx.condition unlock];
  
  return ctx.state == Succeeded;
}

- (BOOL)unmount
{
  struct mount_context ctx = {
    .condition = [[[NSCondition alloc] init] autorelease],
    .state = Waiting
  };
  
  DADiskUnmount (diskRef, 0, mountCallback, &ctx);
  
  [ctx.condition lock];
  while (ctx.state == Waiting)
    [ctx.condition wait];
  [ctx.condition unlock];
  
  return ctx.state == Succeeded;
}

- (NSString *)description
{
  const char *bsdName = DADiskGetBSDName (diskRef);
  
  return [NSString stringWithFormat:@"<CVDisk: %p %s>", self, bsdName];
}

- (uint64_t)freeSpaceAfterFormatting
{
  // Execute newfs_hfs with the -N parameter
  pid_t pid = -1;
  uint64_t ret = 0;
  char *buf = NULL;
  FILE *input = NULL;
  
  int fds[2];
  if (pipe (fds)) {
    perror ("pipe failed");
    return 0;
  }
  
  posix_spawn_file_actions_t file_actions;
  posix_spawn_file_actions_init (&file_actions);
  posix_spawn_file_actions_adddup2 (&file_actions, fds[1], STDOUT_FILENO);
  posix_spawn_file_actions_addclose (&file_actions, fds[0]);
  posix_spawn_file_actions_addclose (&file_actions, fds[1]);
  
  uint64_t mediaSize = [self mediaSize];
  char mediaSizeStr[64];
  sprintf (mediaSizeStr, "%llu", [self mediaSize]);
  
  char * const args[] = { "newfs_hfs", "-N", mediaSizeStr, NULL };
  
  if (posix_spawn (&pid, "/sbin/newfs_hfs", &file_actions, NULL, args, NULL)) {
    perror ("posix_spawn failed");
    posix_spawn_file_actions_destroy (&file_actions);
    goto LEAVE;
  }
  
  posix_spawn_file_actions_destroy (&file_actions);
  
  // We don't need this end of the pipe any more
  close (fds[1]); fds[1] = -1;
  
  input = fdopen (fds[0], "r");
  buf = malloc (4096);
  
  unsigned blockSize = 0;
  unsigned totalBlocks = 0;
  unsigned usedBlocks = 0;
  unsigned thingsRemaining = (1 << 6) - 1;
  
  for (;;) {
    size_t len;
    char *line = fgetln (input, &len);
    
    if (!line) {
      if (ferror (input)) {
	if (errno == EINTR)
	  continue;
	NSLog (@"Error processing output from newfs_hfs: %s!",
	       strerror (errno));
	goto LEAVE;
      }
      break;
    }
    
    if (len > 4095)
      continue;
    
    memcpy (buf, line, len);
    buf[len] = 0;
    char *p = buf;
    
    while (*p == ' ' || *p == '\t')
      ++p;
    
    if (!strncmp (p, "block-size: ", 12)) {
      blockSize = (unsigned)atol (p + 12);
      thingsRemaining &= ~1;
    } else if (!strncmp (p, "total blocks: ", 14)) {
      totalBlocks = (unsigned)atol (p + 14);
      thingsRemaining &= ~2;
    } else if (!strncmp (p, "initial catalog file size: ", 27)) {
      if (!blockSize)
	goto LEAVE;
      usedBlocks += atoll (p + 27) / blockSize;
      thingsRemaining &= ~4;
    } else if (!strncmp (p, "initial extents file size: ", 27)) {
      if (!blockSize)
	goto LEAVE;
      usedBlocks += atoll (p + 27) / blockSize;
      thingsRemaining &= ~8;
    } else if (!strncmp (p, "initial attributes file size: ", 30)) {
      if (!blockSize)
	goto LEAVE;
      usedBlocks += atoll (p + 30) / blockSize;      
      thingsRemaining &= ~16;
    } else if (!strncmp (p, "initial allocation file size: ", 30)) {
      if (!blockSize)
	goto LEAVE;
      usedBlocks += atoll (p + 30) / blockSize;
      thingsRemaining &= ~32;
    }
    if (!thingsRemaining)
      break;
  }
  
  if (thingsRemaining) {
    NSLog (@"Bad output from newfs_hfs!");
    goto LEAVE;
  }
  
  /* Add in the extras, 2 for the volume header, 1 for the
   journal info block, 1 for the initial fsevents file. */
  usedBlocks += 2 + 1 + 1;
  
  // And the journal.  This code is similar to that of newfs_hfs
  if (mediaSize < 128 * 1024 * 1024)
    usedBlocks += 512 * 1024 / blockSize;
  else {
    unsigned journalScale = (unsigned)mediaSize / (100ull * 1024 * 1024 * 1024);
    if (journalScale > 64)
      journalScale = 64;
    uint64_t journalSize = 8ull * 1024 * 1024 * (journalScale + 1);
    if (journalSize > 512 * 1024 * 1024)
      journalSize = 512 * 1024 * 1024;
    usedBlocks += journalSize / blockSize;
  }
  
  ret = (uint64_t)(totalBlocks - usedBlocks) * blockSize;
  
LEAVE:
  if (pid != -1) {
    int status;
    while (waitpid (pid, &status, 0) == -1 && errno == EINTR)
      ;
  }
  
  if (input)
    fclose (input);
  else if (fds[0] != -1)
    close (fds[0]);
  if (fds[1] != -1)
    close (fds[1]);
  if (buf)
    free (buf);
  
  return ret;
}

- (uint64_t)spaceUsed
{
  NSString *mountPoint = [self mountPoint];
  if (!mountPoint)
    return 0;
  
  struct statfs sfs;
  if (statfs ([mountPoint fileSystemRepresentation], &sfs)) {
    perror ("statfs failed");
    return 0;
  }
  
  return (uint64_t)(sfs.f_blocks - sfs.f_bfree) * sfs.f_bsize;
}

@end
