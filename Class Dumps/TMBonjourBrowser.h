/*
 *     Generated by class-dump 3.3.2 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2010 by Steve Nygard.
 */

#import "NSObject.h"

#import "NSNetServiceBrowserDelegate-Protocol.h"
#import "NSNetServiceDelegate-Protocol.h"

@class NSImage, NSMutableArray, NSNetServiceBrowser;

@interface TMBonjourBrowser : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
    NSNetServiceBrowser *_browser;
    NSMutableArray *_netServices;
    NSImage *_serverImage;
}

- (id)_destinationsFromNetService:(id)arg1;
- (id)_dictionaryFromAirPortDiskData:(id)arg1;
- (BOOL)_isLocalNetService:(id)arg1;
- (id)bonjourDestinations;
- (void)dealloc;
- (void)finalize;
- (id)init;
- (void)netService:(id)arg1 didNotResolve:(id)arg2;
- (void)netServiceBrowser:(id)arg1 didFindService:(id)arg2 moreComing:(BOOL)arg3;
- (void)netServiceBrowser:(id)arg1 didRemoveService:(id)arg2 moreComing:(BOOL)arg3;
- (void)netServiceDidResolveAddress:(id)arg1;

@end
