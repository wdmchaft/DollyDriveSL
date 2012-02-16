//
//  ADDExclusionsModel.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ADDExclusionsModel : NSObject
{
    NSMutableArray *treeTopLevel; // Array of ADDExclusionTree objects
}

@property (retain) NSMutableArray *treeTopLevel; // Array of ADDExclusionTree objects

+ (NSSet *)ignoredRootDirs;

- (BOOL)saveBackupStateExcludingRootDirs:(BOOL)excludeRootDirs WithError:(NSError **)error;
- (BOOL)excludeRootDirsExceptUserAndApplicationsWithError:(NSError **)error;
- (BOOL)removeRootDirsExclusionWithError:(NSError **)error;

- (OSStatus)removeExclusionForPath:(NSString *)path;
- (OSStatus)excludePath:(NSString *)path;

- (oneway void)exit;

- (NSString *)validate1:(NSString*)fromClient1;
- (NSString *)validate2:(NSString*)fromClient2;

@end

OSStatus removeExclusionForPath(NSString *path);
OSStatus excludePath(NSString *path);
