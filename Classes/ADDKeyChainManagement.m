//
//  ADDKeyChainManagement.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 9/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDKeyChainManagement.h"
#import "ADDAppConfig.h"
#import "ADDServerConfig.h"

const char *ADDKeychainServiceName = "Dolly Drive Admin";

SecAccessRef createAccess(NSString *accessLabel, NSError **error);

@implementation ADDKeyChainManagement

@synthesize error;

+ (BOOL)passwordExistsInKeychain
{
    return [self passwordFromKeychain] ? YES : NO;
}

NSString *passwordFromKeychain = nil; // otherwise get a keychain warning each time we search

+ (NSString *)passwordFromKeychain
{
    if (passwordFromKeychain)
        return passwordFromKeychain;
    
    UInt32 passwordLength;
    void *passwordData;
    
    ADDServerConfig *config = [[ADDAppConfig sharedAppConfig] serverConfig];
    
    OSStatus status = SecKeychainFindGenericPassword (
                                                      NULL, //CFTypeRef keychainOrArray,
                                                      (UInt32) strlen(ADDKeychainServiceName), //UInt32 serviceNameLength,
                                                      ADDKeychainServiceName, //const char *serviceName,
                                                      (UInt32) [config.afpUsername length], //UInt32 accountNameLength,
                                                      [config.afpUsername cStringUsingEncoding:NSASCIIStringEncoding], //const char *accountName,
                                                      &passwordLength, //UInt32 *passwordLength,
                                                      &passwordData, //void **passwordData,
                                                      NULL //SecKeychainItemRef *itemRef
                                                      );
    
    if (status != 0)
    {
        return nil;
    }
    
    passwordFromKeychain = [[NSString alloc] initWithFormat:@"%.*s", passwordLength, passwordData];
    
    return passwordFromKeychain;
}

+ (void)setDollyPasswordInKeychain:(NSString *)password forUsername:(NSString *)username
{
    passwordFromKeychain = password;
    
    SecKeychainAddGenericPassword(
                                  NULL, //SecKeychainRef keychain,
                                  (UInt32) strlen(ADDKeychainServiceName), //UInt32 serviceNameLength,
                                  ADDKeychainServiceName, //const char *serviceName,
                                  (UInt32) [username length], //UInt32 accountNameLength,
                                  [username cStringUsingEncoding:NSASCIIStringEncoding], //const char *accountName,
                                  (UInt32) [password length], //UInt32 passwordLength,
                                  [password cStringUsingEncoding:NSASCIIStringEncoding], //const void *passwordData,
                                  NULL //SecKeychainItemRef *itemRef          
                                  );

}

+ (void)removeDollyPasswordInKeychainForUsername:(NSString *)username
{
    passwordFromKeychain = nil;
    
    SecKeychainItemRef itemRef;
    
    OSStatus status = SecKeychainFindGenericPassword (
                                                      NULL, //CFTypeRef keychainOrArray,
                                                      (UInt32) strlen(ADDKeychainServiceName), //UInt32 serviceNameLength,
                                                      ADDKeychainServiceName, //const char *serviceName,
                                                      (UInt32) [username length], //UInt32 accountNameLength,
                                                      [username cStringUsingEncoding:NSASCIIStringEncoding], //const char *accountName,
                                                      NULL, //UInt32 *passwordLength,
                                                      NULL, //void **passwordData,
                                                      &itemRef //SecKeychainItemRef *itemRef
                                                      );
    
    if (status == 0)
    {
        status = SecKeychainItemDelete(itemRef);
        if (status != 0)
            NSLog(@"Unable to delete user keychain item: %@", [(NSString *)SecCopyErrorMessageString(status, NULL) autorelease]);
    }
}

- (id)init
{
    if ((self = [super init]))
    {
        OSStatus status;
        if((status = SecKeychainOpen("/Library/Keychains/System.keychain", &keychain)) != 0)
        {
            NSLog(@"Unable to open System keychain: %s",GetMacOSStatusErrorString(status));
            [self release];
            return nil;
        }
    }
    
    return self;
}

- (OSStatus)setItemRef:(SecKeychainItemRef *)itemHandle
         ForServerName:(NSString *)server
                  port:(UInt16)port
                  path:(NSString *)path
           accountName:(NSString *)accountName
{
    OSStatus status = SecKeychainFindInternetPassword (
                                                       keychain, //CFTypeRef keychainOrArray,
                                                       (UInt32)[server length], //UInt32 serverNameLength,
                                                       [server cStringUsingEncoding:NSASCIIStringEncoding], //const char *serverName,
                                                       0, //UInt32 securityDomainLength,
                                                       NULL, //const char *securityDomain,
                                                       (UInt32)[accountName length], //UInt32 accountNameLength,
                                                       [accountName cStringUsingEncoding:NSASCIIStringEncoding], //const char *accountName,
                                                       (UInt32)[path length], //UInt32 pathLength,
                                                       [path cStringUsingEncoding:NSASCIIStringEncoding], //const char *path,
                                                       port, //UInt16 port,
                                                       0, //SecProtocolType protocol,
                                                       0, //SecAuthenticationType authenticationType,
                                                       NULL, //UInt32 *passwordLength,
                                                       NULL, //void **passwordData,
                                                       itemHandle //SecKeychainItemRef *itemRef
                                                       );
    
    return status;
}

- (BOOL) timeMachineKeychainEntryExistsForServerName:(NSString *)server
                                                port:(UInt16)port
                                                path:(NSString *)path
                                         accountName:(NSString *)accountName
{
    SecKeychainItemRef itemRef = NULL;
    
    OSStatus status = [self setItemRef:&itemRef ForServerName:server port:port path:path accountName:accountName];
    
    if (status != 0)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Error reading KeyChain: %s", GetMacOSStatusErrorString(status)]
                                         code:status
                                     userInfo:nil];
        return NO;
    }
    
    BOOL ret = NO;
    
    // there is an entry with that host/port/user, but we didn't check the password to avoid
    // the system keychain extra login requirement - we rely on the helperIsRequired method
    // checking the app password in the keychain
    if (itemRef)
        ret = YES;
    
    if (itemRef)
        CFRelease(itemRef);
    
    return ret;
}

- (BOOL) addOrUpdateTimeMachineKeychainEntryForServerName:(NSString *)server 
                                                     port:(UInt16)port
                                                     path:(NSString *)path
                                              accountName:(NSString *)accountName
                                                 password:(NSString *)password
{
    SecKeychainItemRef itemRef = NULL;
    
    const char *description = "Time Machine Password";
    
    //Create initial access control settings for the item:
    // label for ACLs also seems to be the server 
    SecAccessRef secAccess = createAccess(server, &error);
    
    if (!secAccess)
        return NO;
    
    SecProtocolType protocol = kSecProtocolTypeAFP;
    
    SecKeychainAttribute attrs[] = {
        { kSecLabelItemAttr, (UInt32)[server length], (char *)[server cStringUsingEncoding:NSASCIIStringEncoding] }, // Label seems to always be the server
        { kSecAccountItemAttr, (UInt32)[accountName length], (char *)[accountName cStringUsingEncoding:NSASCIIStringEncoding] },
        { kSecServerItemAttr, (UInt32)[server length], (char *)[server cStringUsingEncoding:NSASCIIStringEncoding] },
        { kSecPortItemAttr, sizeof(UInt16), (int *)&port },
        { kSecProtocolItemAttr, sizeof(SecProtocolType), &protocol },
        { kSecPathItemAttr, (UInt32)[path length], (char *)[path cStringUsingEncoding:NSASCIIStringEncoding] },
        { kSecDescriptionItemAttr, (UInt32)strlen(description), (char *)description }
    };
    
    SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
    
    OSStatus status = 0;
    
    NSString *errorFormat = nil;
    
    if (
        0 == [self setItemRef:&itemRef ForServerName:server port:port path:path accountName:accountName] &&
        itemRef
        )
    {
        status = SecKeychainItemModifyContent (
                                               itemRef, //SecKeychainItemRef itemRef,
                                               &attributes, //const SecKeychainAttributeList *attrList,
                                               (UInt32)[password length], //UInt32 length,
                                               [password cStringUsingEncoding:NSASCIIStringEncoding] //const void *data
                                               );
        
        errorFormat = @"Error modifying KeyChain entry: %s";
    }
    else
    {
        status = SecKeychainItemCreateFromContent(
                                                  kSecInternetPasswordItemClass,
                                                  &attributes,
                                                  (UInt32)[password length],
                                                  [password cStringUsingEncoding:NSASCIIStringEncoding],
                                                  keychain,
                                                  secAccess,
                                                  &itemRef
                                                  );
        
        errorFormat = @"Error creating KeyChain entry: %s";
    }
    
    if (status != 0)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:errorFormat,
                                               [(NSString *)SecCopyErrorMessageString(status, NULL) autorelease]]
                                         code:status
                                     userInfo:nil];
        return NO;
    }
    
    if (secAccess)
        CFRelease(secAccess);
    
    if (itemRef) 
        CFRelease(itemRef);
    
    return YES;
}

- (void)dealloc
{
    CFRelease(keychain);
    
    [super dealloc];
}

@end

SecAccessRef createAccess(NSString *accessLabel, NSError **error)
{
    OSStatus status;
    SecAccessRef secAccess = NULL;
    NSArray *trustedApplications = nil;
    
    SecTrustedApplicationRef writeconfig, netAuthAgent, netAuthSysAgent;
    
    // what if this list changes in future OS version? might want to be config driven?
    // or just roll out an update?
    
    SecTrustedApplicationCreateFromPath(
                                        "/System/Library/PrivateFrameworks/Admin.framework/Resources/writeconfig",
                                        &writeconfig
                                        );
    
    SecTrustedApplicationCreateFromPath(
                                        "/System/Library/CoreServices/NetAuthAgent.app",
                                        &netAuthAgent
                                        );
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/System/Library/CoreServices/NetAuthAgent.app/Contents/Resources/NetAuthSysAgent"])
    {
        SecTrustedApplicationCreateFromPath(
                                            "/System/Library/CoreServices/NetAuthAgent.app/Contents/Resources/NetAuthSysAgent",
                                            &netAuthSysAgent
                                            );
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/System/Library/CoreServices/NetAuthAgent.app/Contents/MacOS/NetAuthSysAgent"])
    {
        SecTrustedApplicationCreateFromPath(
                                            "/System/Library/CoreServices/NetAuthAgent.app/Contents/MacOS/NetAuthSysAgent",
                                            &netAuthSysAgent
                                            );
    }
    else
    {
        if (error)
            *error = [NSError errorWithDomain:[NSString stringWithFormat:@"Error creating KeyChain ACL entry: Unable to locate NetAuthSysAgent"]
                                         code:2
                                     userInfo:nil];
        return NULL;

    }
    trustedApplications = [NSArray arrayWithObjects:(id)writeconfig, (id)netAuthAgent, (id)netAuthSysAgent, nil];
    
    //Create an access object:
    status = SecAccessCreate((CFStringRef)accessLabel,
                             (CFArrayRef)trustedApplications, &secAccess);
    
    if (status != 0)
    {
        //TODO: proper error domain
        if (error)
            *error = [NSError errorWithDomain:[NSString stringWithFormat:@"Error creating KeyChain ACL entry: %s", GetMacOSStatusErrorString(status)]
                                         code:status
                                     userInfo:nil];
        return NULL;
    }
        
    return secAccess;
}
