//
//  ADDExclusionTreeNodeUsers.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/03/11.
//  Copyright 2011 Pumptheory Pty Ltd. All rights reserved.
//

#import "ADDExclusionTreeNodeUsers.h"

#import <CoreServices/CoreServices.h>
#import <Collaboration/Collaboration.h>

#import "ADDExclusionTreeNodeUser.h"
#import "ADDExclusionTreeNodeFolderWithContents.h"

// thank you Dave De Long http://stackoverflow.com/questions/3681895/get-all-users-on-os-x

NSArray *userList();

NSArray *userList()
{
    CSIdentityAuthorityRef defaultAuthority = CSGetLocalIdentityAuthority();
    CSIdentityClass identityClass = kCSIdentityClassUser;
    
    CSIdentityQueryRef query = CSIdentityQueryCreate(NULL, identityClass, defaultAuthority);
    
    CFErrorRef error = NULL;
    CSIdentityQueryExecute(query, 0, &error);
    
    CFArrayRef results = CSIdentityQueryCopyResults(query);
    
    CFIndex numResults = CFArrayGetCount(results);
    
    NSMutableArray * users = [NSMutableArray array];
    for (int i = 0; i < numResults; ++i) {
        CSIdentityRef identity = (CSIdentityRef)CFArrayGetValueAtIndex(results, i);
        
        CBIdentity * identityObject = [CBIdentity identityWithCSIdentity:identity];
        [users addObject:identityObject];
    }
    
    CFRelease(results);
    CFRelease(query);
    
    return users;
}


@implementation ADDExclusionTreeNodeUsers

@synthesize users;

+ (id)usersNode
{
    return [[[self alloc] init] autorelease];
}

- (id)init
{
    if ((self = [super init]))
    {
        NSMutableSet *userDirs = [NSMutableSet setWithCapacity:10];
        
        // user dirs can be anywhere, so we interrogate the directory first
        self.users = userList();
        for (CBIdentity *user in users)
        {
            if ([[user fullName] isEqualToString:@"macports"])
                continue;
            
            ADDExclusionTreeNodeUser *userNode = [ADDExclusionTreeNodeUser userNodeWithIdentity:user];
            userNode.parent = self;
            [self addChild:userNode];
            [userDirs addObject:[userNode representedPath]];
            
        }
        
        // but we also want to include any regular dirs in the /Users directory that aren't tied
        // to a user to capture eg. Shared, Deleted and archived users
        
        for (NSString *subdir in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Users" error:NULL])
        {
            BOOL isDirectory = NO;
            NSString *fullPath = [@"/Users" stringByAppendingPathComponent:subdir];
            [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
            
            // seems to auto-skip hidden directories, but just in case
            if (isInvisbleDir(fullPath))
                continue;
            
            if (!isDirectory)
                continue;
            
            if ([userDirs containsObject:fullPath])
                continue;

            [self addChild:[ADDExclusionTreeNodeFolderWithContents nodeWithParent:self path:fullPath depth:0 maxDepth:2]];
        }
    }
    
    return self;
}

- (NSString *)title
{
    return @"Users";
}

+ (NSImage *)iconForNode:(ADDExclusionTreeNodeBase *)node
{
    return [[NSWorkspace sharedWorkspace] iconForFile:@"/Users"];
}

// the volumes parent is virtual, so we need to bubble writing the backup state down to each volume
// even if all are off
- (OSStatus)saveBackupState
{
    for (ADDExclusionTreeNodeBase *child in self.children)
    {
        OSStatus ret = [child saveBackupState];
        if (ret != noErr)
            return ret;
    }
    
    return noErr;
}

- (BOOL)isExcludedFromBackup
{
    return NO;
}

- (NSInteger)checkboxState
{
    if ([self allChildrenSelected])
        return NSOnState;
    
    if ([self hasSelectedChildren])
        return NSMixedState;
    
    return NSOffState;
}

- (void)setSizeOnDiskIfAllChildrenSized
{
    BOOL queue = YES;
    
    for (ADDExclusionTreeNodeBase *child in self.children)
    {
        if (!child.sizeOnDisk)
        {
            queue = NO;
            break;
        }
    }
    
    if (queue)
    {
        unsigned long long size = 0;
        for (ADDExclusionTreeNodeBase *child in self.children)
            size += child.sizeOnDisk;
        
        self.sizeOnDisk = size;
        
        NSNotification *notif = [NSNotification notificationWithName:(NSString *)ADDExclusionTreeNodeSizeOnDiskSetNotification object:nil];
        
        if (!operationCancelled)
            [[NSNotificationQueue defaultQueue] enqueueNotification:notif
                                                       postingStyle:NSPostNow];        
    }
}

- (void)dealloc
{
    ReleaseAndNil(users);
    
    [super dealloc];
}

@end
