//
//  ADDKeyChainManagement.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Security/Security.h>

extern const char * ADDKeychainServiceName;

@interface ADDKeyChainManagement : NSObject 
{
    SecKeychainRef keychain;
    NSError *error;
}

@property (retain) NSError *error;

// These are for the Dolly Drive login entry
+ (BOOL)passwordExistsInKeychain;
+ (NSString *)passwordFromKeychain;
+ (void)setDollyPasswordInKeychain:(NSString *)password forUsername:(NSString *)username;
+ (void)removeDollyPasswordInKeychainForUsername:(NSString *)username;

// These are for the Time Machine system entry

//NB: the strings are currently assumed to be ascii - ie. no 16 bit characters
- (BOOL) timeMachineKeychainEntryExistsForServerName:(NSString *)server 
                                                port:(UInt16)port 
                                                path:(NSString *)path
                                         accountName:(NSString *)accountName;

//NB: You can only write to the system keychain as root
- (BOOL) addOrUpdateTimeMachineKeychainEntryForServerName:(NSString *)server 
                                                     port:(UInt16)port
                                                     path:(NSString *)path
                                              accountName:(NSString *)accountName
                                                 password:(NSString *)password;

@end
