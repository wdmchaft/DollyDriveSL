//
//  ADDServerConn.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDServerRequestJSON.h"

#import "YAJL.h"
#import "ADDAppConfig.h"
#import "ADDKeyManagement.h"
#import "ADDKeyChainManagement.h"

static NSString *userInfoSubmissionURLFormatString = @"https://admin01.dollydrive.com:%u/api/1/client_account_info";
static NSString *createSparseBundleURLFormatString = @"https://admin01.dollydrive.com:%u/api/1/client_create_sparsebundle";
static NSString *sharedSecret = @"f3c85dca78aa40a81beff92139e40a5a";

@interface ADDServerRequestJSON (Private)

- (void)sendUserDetailsRequestFinished:(ASIHTTPRequest *)request;
- (void)createSparseBundleRequestFinished:(ASIHTTPRequest *)request;

@end

@implementation ADDServerRequestJSON

@synthesize delegate;
@synthesize asiRequest;
@synthesize error;
@synthesize requestType;

- (id)init
{
    if ((self = [super init]))
    {
        [ASIHTTPRequest setDefaultTimeOutSeconds:70];
    }
    
    return self;
}

- (void)sendUserDetails:(NSDictionary *)userDetails
{
    if (requestType)
        [NSException raise:@"Cannot reuse ADDServerRequestJSON object" 
                    format:@"The application has attempted to reuse an ADDServerRequestJSON object which is not allowed"];

    //TODO: should be creating the user details dict in here from the server config singleton etc. not the controller...
    
    NSUInteger apiPort = [[ADDAppConfig sharedAppConfig] apiPort];
    NSString* userInfoSubmissionURLString = [NSString stringWithFormat:userInfoSubmissionURLFormatString, apiPort];
    
    NSURL *url = [NSURL URLWithString:userInfoSubmissionURLString];
    
    self.asiRequest = [ASIFormDataRequest requestWithURL:url];
    [self.asiRequest setDelegate:self];
    [self.asiRequest setValidatesSecureCertificate:NO]; // self-signed test cert
    
    for (NSString *key in userDetails)
        [self.asiRequest addPostValue:[userDetails objectForKey:key] forKey:key];
        
    [self.asiRequest addPostValue:sharedSecret forKey:ADDServerRequestSharedSecretFieldName];
    
    requestType = ADDServerRequestTypeSendUserDetails;
    
    [self.asiRequest startAsynchronous];
}

- (void)createSparseBundleWithPassword:(NSString *)password;
{
    if (requestType)
        [NSException raise:@"Cannot reuse ADDServerRequestJSON object" 
                    format:@"The application has attempted to reuse an ADDServerRequestJSON object which is not allowed"];
    
    //TODO: should be creating the user details dict in here from the server config singleton etc. not the controller...
    
    NSUInteger apiPort = [[ADDAppConfig sharedAppConfig] apiPort];
    NSString* createSparseBundleURLString = [NSString stringWithFormat:createSparseBundleURLFormatString, apiPort];

    NSURL *url = [NSURL URLWithString:createSparseBundleURLString];
    
    self.asiRequest = [ASIFormDataRequest requestWithURL:url];
    [self.asiRequest setDelegate:self];
    [self.asiRequest setValidatesSecureCertificate:NO]; // self-signed test cert
    
    ADDServerConfig *config = [[ADDAppConfig sharedAppConfig] serverConfig];
    
    [self.asiRequest addPostValue:password forKey:ADDServerRequestPasswordFieldName];
    [self.asiRequest addPostValue:config.afpUsername forKey:ADDServerRequestUsernameFieldName];
    [self.asiRequest addPostValue:sharedSecret forKey:ADDServerRequestSharedSecretFieldName];
    
    requestType = ADDServerRequestTypeCreateSparseBundle;
    
    [self.asiRequest startAsynchronous];
}

- (void)requestFinished:(ASIHTTPRequest *)request
{
    switch (requestType)
    {
        case ADDServerRequestTypeSendUserDetails:
            [self sendUserDetailsRequestFinished:request];
            break;
            
        case ADDServerRequestTypeCreateSparseBundle:
            [self createSparseBundleRequestFinished:request];
            break;
    }
}

- (void)createSparseBundleRequestFinished:(ASIHTTPRequest *)request
{
    NSDictionary *dict = nil;
    @try {
        dict = [[request responseData] yajl_JSON];
    }
    @catch (NSException * e) {
        NSLog(@"Exception decoding JSON: %@ Content returned from server: %@", e, [[request responseString] substringToIndex:2048]);
        // this will be handled below as a matter of course due to lack of dict
    }
    
    if ([request responseStatusCode] != 200)
    {
        //TODO: proper error handling
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Dolly Drive server returned an error: %@", [request responseStatusMessage]]
                                         code:request.responseStatusCode
                                     userInfo:nil];
        [delegate requestFailedTemporarily:self];
    }
    else if (
             !dict ||
             ![[dict objectForKey:ADDServerResponseSuccessKey] isKindOfClass:[NSNumber class]] ||
             ![[dict objectForKey:ADDServerResponseSuccessKey] boolValue]
             )
    {
        //TODO: proper error handling
        NSString *errorString = @"Dolly Drive server returned an invalid response.";
        if ([dict objectForKey:ADDServerResponseErrorStringKey])
        {
            errorString = [errorString stringByAppendingFormat:@"%@",
                           [dict objectForKey:ADDServerResponseErrorStringKey]];
        }
        NSLog(@"bad or missing key in server JSON response: %@", [request responseString]);
        self.error = [NSError errorWithDomain:errorString
                                         code:200
                                     userInfo:nil];
        [delegate requestFailedTemporarily:self];
    }
    else 
    {
        [delegate requestCompleted:self withConfig:nil];
    }
}

- (void)sendUserDetailsRequestFinished:(ASIHTTPRequest *)request
{
    NSDictionary *dict = nil;
    @try {
        dict = [[request responseData] yajl_JSON];
    }
    @catch (NSException * e) {
        NSLog(@"Exception decoding JSON: %@ Content returned from server: %@", e, [[request responseString] substringToIndex:2048]);
        // this will be handled below as a matter of course due to lack of dict
    }
    
    NSArray *tunnelServersReponse = nil;
    if ([dict isKindOfClass:[NSDictionary class]])
        tunnelServersReponse = [dict objectForKey:ADDServerResponseTunnelServersArrayKey];
    
    if ([request responseStatusCode] != 200)
    {
        //TODO: proper error handling
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Dolly Drive server returned an error: %@", [request responseStatusMessage]]
                                         code:request.responseStatusCode
                                     userInfo:nil];
        [delegate requestFailedTemporarily:self];
    }
    else if (
             ![dict objectForKey:ADDServerResponseSparseBundleCreatedKey] ||
             ![dict objectForKey:ADDServerResponseVolumeNameKey] ||
             ![dict objectForKey:ADDServerResponseBonjourPortKey] ||
             ![dict objectForKey:ADDServerResponseAFPShareSizeKey] ||
             [tunnelServersReponse count] == 0 ||
             ![[tunnelServersReponse objectAtIndex:0] isKindOfClass:[NSDictionary class]] ||
             ![(NSDictionary *)[tunnelServersReponse objectAtIndex:0] objectForKey:ADDServerResponseTunnelServerUsernameKey] ||
             ![(NSDictionary *)[tunnelServersReponse objectAtIndex:0] objectForKey:ADDServerResponseTunnelServerHostnameKey] ||
             ![(NSDictionary *)[tunnelServersReponse objectAtIndex:0] objectForKey:ADDServerResponseTunnelServerPortKey]
             )
    {
        //TODO: proper error handling
        NSLog(@"bad or missing key in server JSON response: %@", [request responseString]);
        self.error = [NSError errorWithDomain:@"Dolly Drive server returned an invalid response."
                                         code:200
                                     userInfo:nil];
        [delegate requestFailedTemporarily:self];
    }
    else 
    {
        ADDServerConfig *config;
        if ([ADDServerConfig configFileExists])
        {
            config = [[ADDServerConfig alloc] initFromFile];
        }
        else 
        {
            config = [[ADDServerConfig alloc] init];
        }
        [config autorelease];
        
        NSMutableArray *tunnelServers = [NSMutableArray arrayWithCapacity:5];
        
        //config.tunnelServers = [dict objectForKey:ADDServerConfigTunnelServersKey];
        //config.tunnelUser = [dict objectForKey:ADDServerConfigTunnelUserKey];
        config.afpVolumeName = [dict objectForKey:ADDServerResponseVolumeNameKey];
        config.sparseBundleCreated = [dict objectForKey:ADDServerResponseSparseBundleCreatedKey];
        config.bonjourPort = [dict objectForKey:ADDServerResponseBonjourPortKey];
        config.volumeUUID = [dict objectForKey:ADDServerResponseVolumeUUIDKey];
        config.tunnelArgs = [dict objectForKey:ADDServerResponseTunnelArgsKey];
        config.quotaSize = [dict objectForKey:ADDServerResponseAFPShareSizeKey];
        
        if (!config.tunnelArgs)
        {
            config.tunnelArgs = [NSArray arrayWithObjects:
                                 @"-C",
                                 @"-q",
                                 @"-T",
                                 @"-c",
                                 @"blowfish-cbc,aes128-cbc,3des-cbc",
                                 @"-o",
                                 @"StrictHostKeyChecking=no",
                                 nil];
                                 
        }

        
        for (NSDictionary *tunnelServer in (NSArray *)[dict objectForKey:ADDServerResponseTunnelServersArrayKey])
        {
            //TODO: put these strings in a header file shared with the ssh helper
            NSDictionary *tunnelServerConfigDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                    [tunnelServer objectForKey:ADDServerResponseTunnelServerHostnameKey], @"host",
                                                    [tunnelServer objectForKey:ADDServerResponseTunnelServerPortKey], @"port",
                                                    [tunnelServer objectForKey:ADDServerResponseTunnelServerUsernameKey], @"user",
                                                    nil];
            
            [tunnelServers addObject:tunnelServerConfigDict];
            
            //[tunnelServers addObject:[tunnelServer objectForKey:ADDServerResponseTunnelServerHostnameKey]];
            //config.tunnelUser = [tunnelServer objectForKey:ADDServerResponseTunnelServerUsernameKey];
            //config.tunnelPort = [tunnelServer objectForKey:ADDServerResponseTunnelServerPortKey];
        }
        
        config.tunnelServers = tunnelServers;  
        
        //TODO: refactor - the request and config objects are hopelessly and incorrectly overlapping, and it's not even server config!
        config.tunnelIdentity = ((ADDKeyManagement *)[[[ADDKeyManagement alloc] init] autorelease]).privateKeyFilePath;
        
        [delegate requestCompleted:self withConfig:config];
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    self.error = request.error;
    [delegate requestFailedTemporarily:self];
}


- (void)dealloc
{
    [asiRequest setDelegate:nil];
    [asiRequest release];
    asiRequest = nil;
    delegate = nil;
    
    [super dealloc];
}

@end
