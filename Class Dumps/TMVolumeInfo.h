/*
 *     Generated by class-dump 3.3.2 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2010 by Steve Nygard.
 */

#import "NSObject.h"

@interface TMVolumeInfo : NSObject
{
}

+ (id)_fstypenameForMountPoint:(id)arg1;
+ (void)asyncEjectMountPoint:(id)arg1;
+ (id)bytesUsedOnMountpoint:(id)arg1;
+ (int)fileSystemNumberForPath:(id)arg1;
+ (BOOL)isDiskImageMountPoint:(id)arg1;
+ (BOOL)isLocalMountPoint:(id)arg1;
+ (BOOL)isVolume:(id)arg1;
+ (BOOL)isVolumeACFS:(id)arg1;
+ (BOOL)isVolumeCaseSensitive:(id)arg1;
+ (BOOL)isVolumeExFAT:(id)arg1;
+ (BOOL)isVolumeFAT:(id)arg1;
+ (BOOL)isVolumeHFSPlus:(id)arg1;
+ (BOOL)isVolumeNTFS:(id)arg1;
+ (BOOL)isVolumeZFS:(id)arg1;
+ (short)volumeRefNumForPath:(id)arg1;

@end

