//
//  ADDServerConn.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ASIFormDataRequest.h"
#import "ADDServerConfig.h"

typedef enum {
    ADDServerRequestTypeSendUserDetails,
    ADDServerRequestTypeCreateSparseBundle
} ADDServerRequestType;

@class ADDServerRequestJSON;

@protocol ADDServerRequestDelegate

@required

- (void)requestFailedTemporarily:(ADDServerRequestJSON *)request;
- (void)requestCompleted:(ADDServerRequestJSON *)request withConfig:(ADDServerConfig *)response;

@end


@interface ADDServerRequestJSON : NSObject <ASIHTTPRequestDelegate>
{
    id <ADDServerRequestDelegate> delegate;
    ASIFormDataRequest *asiRequest;
    NSError *error;
    ADDServerRequestType requestType;
}

@property (assign) id <ADDServerRequestDelegate> delegate;
@property (retain) ASIFormDataRequest *asiRequest;
@property (retain) NSError *error;
@property (readonly) ADDServerRequestType requestType;

// not entirely sure these should be combined in the same class...
- (void)sendUserDetails:(NSDictionary *)userDetails;
- (void)createSparseBundleWithPassword:(NSString *)password;

@end

#define ADDServerRequestUsernameFieldName @"username"
#define ADDServerRequestPasswordFieldName @"password"
#define ADDServerRequestMacAddressFieldName @"mac_address"
#define ADDServerRequestOSVersionFieldName @"os_version"
#define ADDServerRequestPublicKeyFieldName @"public_key"
#define ADDServerRequestUUIDFieldName @"client_uuid"
#define ADDServerRequestComputerNameFieldName @"client_name"
#define ADDServerRequestAppVersionFieldName @"client_version"
#define ADDServerRequestSharedSecretFieldName @"secret"

#define ADDServerResponseSuccessKey @"success"
#define ADDServerResponseErrorStringKey @"error"
#define ADDServerResponseSparseBundleCreatedKey @"sparse_bundle_created"
#define ADDServerResponseVolumeNameKey @"share_name"
#define ADDServerResponseBonjourPortKey @"bonjour_port"
#define ADDServerResponseAFPShareSizeKey @"afp_share_size"
#define ADDServerResponseVolumeUUIDKey @"volume_uuid"
#define ADDServerResponseTunnelArgsKey @"tunnel_args"

#define ADDServerResponseTunnelServersArrayKey @"dolly_servers"
#define ADDServerResponseTunnelServerUsernameKey @"ssh_username"
#define ADDServerResponseTunnelServerHostnameKey @"ssh_hostname"
#define ADDServerResponseTunnelServerPortKey @"ssh_port"
