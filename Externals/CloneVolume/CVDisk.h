/*
 *  CVDisk.h
 *  CloneVolume
 *
 *  Created by Pumptheory P/L on 12/01/11.
 *  Copyright 2011 Pumptheory P/L. All rights reserved.
 *
 */

@interface CVDisk : NSObject {
  DADiskRef diskRef;
  NSImage *image;
}

+ (CVDisk *)diskWithDiskRef:(DADiskRef)diskRef;
+ (CVDisk *)diskWithMountPath:(NSString*)mountPath;
- (CVDisk *)initWithDiskRef:(DADiskRef)diskRef;

@property (readonly) NSString *name;
@property (readonly) NSImage *image;
@property (readonly) DADiskRef diskRef;
@property (readonly) NSString *bsdName;
@property (readonly) NSString *devicePath;
@property (readonly) BOOL isMounted;
@property (readonly) NSString *mountPoint;
@property (readonly) NSString *volumeKind;
//jaa
@property (readonly) NSString *volumeUUID;

@property (readonly) NSString *mediaContent;
@property (readonly) BOOL mediaWhole;
@property (readonly) uint64_t spaceUsed;

- (BOOL)isTargetDisk;
- (BOOL)isSourceDisk;
- (BOOL)mountPrivately;
- (BOOL)mount;
- (BOOL)unmount;

- (uint64_t)mediaSize;

- (uint64_t)freeSpaceAfterFormatting;

- (BOOL)renameTo:(NSString *)newName;

@end
