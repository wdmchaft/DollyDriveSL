/*
 *     Generated by class-dump 3.3.2 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2010 by Steve Nygard.
 */

#import "NSObject.h"

@class NSDictionary, NSMutableDictionary;

@interface TMBackupClientState : NSObject
{
    char *_notifyString;
    NSDictionary *_currentStatus;
    NSMutableDictionary *_persistentStatusEntries;
    int _lock;
}

- (void)clearPersistentState;
- (void)dealloc;
- (void)doPostNotify:(id)arg1;
- (id)initWithClientID:(id)arg1;
- (void)postNotify;
- (void)setPersistentStateValue:(id)arg1 forKey:(id)arg2;
- (void)setStatus:(id)arg1;
- (id)status;

@end

