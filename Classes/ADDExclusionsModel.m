//
//  ADDExclusionsModel.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionsModel.h"

#import "ADDExclusionTreeNodeApplications.h"
#import "ADDExclusionTreeNodeVolumes.h"
#import "ADDExclusionTreeNodeUsers.h"

@implementation ADDExclusionsModel

@synthesize treeTopLevel;

+ (NSSet *)ignoredRootDirs
{
    return  [NSSet setWithObjects:
             @"/Users",
             @"/Applications",
             @"/Volumes",
             @"/net",
             @"/Network",
             @"/System",
             @"/cache",
             @"/dev",
             @"/etc",
             @"/private",
             @"/home",
             @"/sbin",
             @"/bin",
             @"/tmp",
             @"/usr",
             @"/var",
             @"/.Trashes",
             @"/Library/Caches",
             nil];
}

+ (NSSet *)excludedRootFiles
{
    return [NSSet setWithObjects:
            @"/.MobileBackups",
            @"/.Spotlight-V100",
            @"/.dbfseventsd",
            @"/.file",
            @"/.fseventsd",
            @"/.hotfiles.btree",
            @"/.vol",
            @"/mach_kernel",
            nil];
}

- (id) init
{
    if ((self = [super init]))
    {
        self.treeTopLevel = [NSMutableArray arrayWithCapacity:2];
        
        [self.treeTopLevel addObject:[ADDExclusionTreeNodeApplications applicationsNode]];
        
        if ([ADDExclusionTreeNodeVolumes hasVolumes])
            [self.treeTopLevel addObject:[ADDExclusionTreeNodeVolumes volumesNode]];
        
        [self.treeTopLevel addObject:[ADDExclusionTreeNodeUsers usersNode]];
                
        // need to wait until tree is created to check backup status and start queues so children already exist
        for (ADDExclusionTreeNodeBase *node in self.treeTopLevel)
        {
            [node updateBackupStatus];
        }
        [ADDExclusionTreeNodeBase setAllQueuesSuspended:NO];
    }
    
    return self;
}

- (BOOL)saveBackupStateExcludingRootDirs:(BOOL)excludeRootDirs WithError:(NSError **)error;
{
    OSStatus err;
    
    for (ADDExclusionTreeNodeBase *node in self.treeTopLevel)
    {
        if (((err = [node saveBackupState]) != noErr))
        {
            // TODO: better error handling
            if (error)
                *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
            return NO;
        }
    }
    
    if (excludeRootDirs) {
        if (![self excludeRootDirsExceptUserAndApplicationsWithError:error])
            return NO;
    }
    else 
    {
        if (![self removeRootDirsExclusionWithError:error])
            return NO;
    }
    
    if (error)
        *error = nil;
    
    return YES;
}

OSStatus excludePath(NSString *path)
{
    CFURLRef url = CFURLCreateWithFileSystemPath (
                                                  NULL, //CFAllocatorRef allocator,
                                                  (CFStringRef)path, //CFStringRef filePath,
                                                  kCFURLPOSIXPathStyle, //CFURLPathStyle pathStyle,
                                                  true //Boolean isDirectory
                                                  );
    
    Boolean isExcluded = CSBackupIsItemExcluded (
                                                 url, //CFURLRef item,
                                                 NULL //Boolean * excludeByPath
                                                 );
    
    OSStatus ret = noErr;
    
    if (!isExcluded)
    {
        NSLog(@"Adding '%@' to exclusion set", path);
        
        ret = CSBackupSetItemExcluded (
                                       url, //CFURLRef item,
                                       true, //Boolean exclude,
                                       true //Boolean excludeByPath
                                       );
    }
    
    CFRelease(url);
    
    return ret;
}

- (OSStatus)excludePath:(NSString *)path
{
    return excludePath(path);
}

OSStatus removeExclusionForPath(NSString *path)
{
    CFURLRef url = CFURLCreateWithFileSystemPath (
                                                  NULL, //CFAllocatorRef allocator,
                                                  (CFStringRef)path, //CFStringRef filePath,
                                                  kCFURLPOSIXPathStyle, //CFURLPathStyle pathStyle,
                                                  true //Boolean isDirectory
                                                  );
    
    Boolean excludeByPath;
    Boolean isExcluded = CSBackupIsItemExcluded (
                                                 url, //CFURLRef item,
                                                 &excludeByPath //Boolean * excludeByPath
                                                 );
    
    OSStatus ret = noErr;
    
    if (isExcluded)
    {
        if (excludeByPath)
        {
            NSLog(@"Adding '%@' to exclusion set", path);
            
            ret = CSBackupSetItemExcluded (
                                           url, //CFURLRef item,
                                           false, //Boolean exclude,
                                           true //Boolean excludeByPath
                                           );
        }
        else 
        {
            NSLog(@"not attempting to remove exclusion from '%@' since it seems to be excluded by metadata", path);
        }
    }
    
    CFRelease(url);
    
    return ret;
}

- (OSStatus)removeExclusionForPath:(NSString *)path
{
    return removeExclusionForPath(path);
}

- (BOOL)excludeRootDirsExceptUserAndApplicationsWithError:(NSError **)error
{
    for (NSString *path in [[self class] ignoredRootDirs])
    {
        // these are ignored for display, but don't want to exclude them from backup
        if ([path isEqualToString:@"/Users"])
            continue;
        
        if ([path isEqualToString:@"/Applications"])
            continue;
        
        if ([path isEqualToString:@"/Volumes"])
            continue;
        
        // issues un-excluding these - they are tiny anyway
        if ([path isEqualToString:@"/net"])
            continue;
        
        if ([path isEqualToString:@"/Network"])
            continue;
        
        OSStatus ret = excludePath(path);
        
        if (ret != noErr)
        {
            NSLog(@"error %d (%s) excluding dir: %@", (int)ret, GetMacOSStatusErrorString(ret), path);
             if (error)
                *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
            
            return NO;
        }
    }
    
    // non-directories we always want to exclude
    for (NSString *path in [[self class] excludedRootFiles])
        excludePath(path);
    
    
    return YES;
}

- (BOOL)removeRootDirsExclusionWithError:(NSError **)error
{
    for (NSString *path in [[self class] ignoredRootDirs])
    {
        // these are ignored for display, but don't want to exclude them from backup
        if ([path isEqualToString:@"/Users"])
            continue;
        
        if ([path isEqualToString:@"/Applications"])
            continue;
        
        if ([path isEqualToString:@"/Volumes"])
            continue;
        
        // issues un-excluding these - they are tiny anyway
        if ([path isEqualToString:@"/net"])
            continue;
        
        if ([path isEqualToString:@"/Network"])
            continue;                
        
        OSStatus ret = removeExclusionForPath(path);
        
        if (ret != noErr)
        {
            NSLog(@"error %d (%s) removing exclusion from dir: %@", (int)ret, GetMacOSStatusErrorString(ret), path);
            //TODO: better error handling
            if (error)
                *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
            
            return NO;
        }
    }
    
    for (NSString *path in [[self class] excludedRootFiles])
    {
        OSStatus ret = removeExclusionForPath(path);    
        
        if (ret != noErr)
        {
            NSLog(@"error %d (%s) removing exclusion from %@", (int)ret, GetMacOSStatusErrorString(ret), path);
            //TODO: better error handling
            if (error)
                *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
            
            return NO;
        }
    }
    
    return YES;
}

- (void)cleanup
{
    [ADDExclusionTreeNodeBase cancelAllQueues];
    [ADDExclusionTreeNodeBase waitForAllQueuesToFinish];
    [ADDExclusionTreeNodeBase setAllQueuesSuspended:YES];
    
    ReleaseAndNil(treeTopLevel);
}

BOOL ADDExclusionsHelper_shouldKeepRunning;

- (oneway void)exit
{
    [self cleanup];
    
    ADDExclusionsHelper_shouldKeepRunning = NO;
    
    [[NSConnection defaultConnection] removeRunLoop:[NSRunLoop currentRunLoop]];
	//    exit(0); //TODO: do this better...
}

- (void)dealloc
{
    [self cleanup];
    [super dealloc];
}

@end
