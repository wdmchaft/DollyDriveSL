//
//  ADDKeyManagement.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDKeyManagement.h"
#import "ADDAppConfig.h"

@interface ADDKeyManagement (Private)

- (void) taskDidTerminate:(NSNotification *)notif;

@end

@implementation ADDKeyManagement

@synthesize error;
@synthesize delegate;
@synthesize genKeyTask;

- (NSString *)publicKeyFilePath
{
    return [[ADDAppConfig sharedAppConfig].supportDirectory stringByAppendingPathComponent:@"tunnel_identity.pub"];
}

- (NSString *)privateKeyFilePath
{
    return [[ADDAppConfig sharedAppConfig].supportDirectory stringByAppendingPathComponent:@"tunnel_identity"];
}

- (BOOL)keyPairExistsForEmail:(NSString *)email
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:self.privateKeyFilePath])
        return NO;
    
    if (![fileManager fileExistsAtPath:self.publicKeyFilePath])
        return NO;
    
    NSError *tmpError = nil;
    NSString *pubKey = [NSString stringWithContentsOfFile:self.publicKeyFilePath encoding:NSASCIIStringEncoding error:&tmpError];
    if (
        tmpError ||
        !(
          [pubKey hasSuffix:[NSString stringWithFormat:@" %@\n", email]] ||
          [pubKey hasSuffix:[NSString stringWithFormat:@" %@", email]]
          )
        )
    {
        //TODO: if fails to remove need to be able to alert user, otherwise will hang
        // waiting for answer to prompt
        [fileManager removeItemAtPath:self.privateKeyFilePath error:nil];
        [fileManager removeItemAtPath:self.publicKeyFilePath error:nil];
        return NO;
    }
    
    return YES;
}

- (void)generateKeyPairWithEmail:(NSString *)email
{
    NSArray *args = [NSArray arrayWithObjects:
                     @"-t",
                     @"dsa",
                     @"-f",
                     self.privateKeyFilePath,
                     @"-C",
                     email,
                     @"-P",
                     @"",
                     nil];
    
    self.genKeyTask = [[[NSTask alloc] init] autorelease];
    [genKeyTask setArguments:args];
    [genKeyTask setLaunchPath:@"/usr/bin/ssh-keygen"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskDidTerminate:) 
                                                 name:NSTaskDidTerminateNotification
                                               object:genKeyTask];
    
    [genKeyTask launch];
}

- (void)taskDidTerminate:(NSNotification *)notif
{
    if (genKeyTask != [notif object])
    {
        // the task has been replaced in the mean time
        // should probably stop and release...
        return;
    }
    
    if ([genKeyTask terminationStatus] == 0)
    {
        // want to make sure the keys are mode 0600
        NSDictionary *attribs = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0600]
                                                            forKey:NSFilePosixPermissions];
        [[NSFileManager defaultManager] setAttributes:attribs ofItemAtPath:[self privateKeyFilePath] error:nil];
        [[NSFileManager defaultManager] setAttributes:attribs ofItemAtPath:[self publicKeyFilePath] error:nil];
        
        [delegate keyPairGenerated:self];
    }
    else 
    {
        [delegate keyPairGenerationFailed:self];
    }
}

- (void)dealloc
{
    delegate = nil;
    [error release];
    error = nil;
    [genKeyTask release];
    genKeyTask = nil;
    
    [super dealloc];
}

@end
