//
//  ADDKeyManagement.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ADDKeyManagement;

@protocol ADDKeyManagementDelegate

- (void)keyPairGenerated:(ADDKeyManagement *)addKeyManagement;
- (void)keyPairGenerationFailed:(ADDKeyManagement *)addKeyManagement;

@end


@interface ADDKeyManagement : NSObject
{
    NSError *error;
    id <ADDKeyManagementDelegate> delegate;
    NSTask *genKeyTask;
}

@property (readonly) NSString *privateKeyFilePath;
@property (readonly) NSString *publicKeyFilePath;
@property (retain) NSError *error;
@property (assign) id <ADDKeyManagementDelegate> delegate;
@property (retain) NSTask *genKeyTask;

- (BOOL)keyPairExistsForEmail:(NSString *)emails;
- (void)generateKeyPairWithEmail:(NSString *)email;


@end
