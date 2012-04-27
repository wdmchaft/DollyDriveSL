//
//  ADDAskUserDetailsView.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDAskUserDetailsVC.h"

#import "ADDGetPrimaryMACAddress.h"
#import "ADDAppConfig.h"
#import "ADDMainWindowController.h"
#import "ADDKeyChainManagement.h"

#import "ASIFormDataRequest.h"

#import <SystemConfiguration/SystemConfiguration.h>

#include <unistd.h>
#include <time.h>

#import "UKCrashReporter.h"

@interface ADDAskUserDetailsVC (Private)

- (void)setupView;
- (void)submitToServer;
- (void)submitCheckKeyPair;

@end

// why do we have to redefine this?
int	 gethostuuid(uuid_t, const struct timespec *);

@implementation ADDAskUserDetailsVC

@synthesize username;
@synthesize password;
@synthesize addRequest;
@synthesize progressSheetLabel;
@synthesize keyMgmt;

- (void)forgottenPassword:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://10.0.4.9:30001/my_account/forgot_password"]];
}

- (void)awakeFromNib
{
    [self setTitle:@"Enter Dolly Drive Account Details"];

    [forgottenPasswordField setDelegate:self];
    [forgottenPasswordField setAction:@selector(forgottenPassword:)];
    
    [self.windowController.window setDefaultButtonCell:[loginButton cell]];
    
    [self performSelector:@selector(setupView) withObject:nil afterDelay:0.0];    
}


- (void)setupView
{
    // all this stuff should be refactored into the request classes and the window controller should
    // bypass this view altogether if u/p exist

    // don't try to load the server config if there was a crash
    
    BOOL didCrash = UKCrashReporterCheckForCrash();

    if ([ADDServerConfig configFileExists] && !didCrash)
    {
        [ADDAppConfig sharedAppConfig].serverConfig = [[[ADDServerConfig alloc] initFromFile] autorelease];
        self.username = [ADDAppConfig sharedAppConfig].serverConfig.afpUsername;
        if ([ADDKeyChainManagement passwordExistsInKeychain])
        {
            self.password = [ADDKeyChainManagement passwordFromKeychain];
            [self submit:nil];
        }
        else 
        {
            [self.windowController.window makeFirstResponder:passwordField];
        }
    }
}

- (IBAction)submit:(id)sender
{
    [progressIndicator startAnimation:self];
    
    [NSApp beginSheet:progressSheet
       modalForWindow:[self.windowController window]
        modalDelegate:nil
       didEndSelector:NULL
          contextInfo:nil];
    
    self.keyMgmt = [[[ADDKeyManagement alloc] init] autorelease];
    
    if ([self.keyMgmt keyPairExistsForEmail:username])
    {
        self.progressSheetLabel = @"Contacting the Dolly Drive servers";
        [self performSelector:@selector(submitToServer) withObject:nil afterDelay:0.1];
    }
    else 
    {
        self.progressSheetLabel = @"Generating Key Pair";
        [self performSelector:@selector(submitCheckKeyPair) withObject:nil afterDelay:0.1];
    }
}

- (void)submitCheckKeyPair
{
    self.keyMgmt.delegate = self;
    [self.keyMgmt generateKeyPairWithEmail:username];
}

- (void)keyPairGenerated:(ADDKeyManagement *)addKeyManagement
{
    self.progressSheetLabel = @"Contacting the Dolly Drive servers";
    [self performSelector:@selector(submitToServer) withObject:nil afterDelay:0.1];
}

- (void)keyPairGenerationFailed:(ADDKeyManagement *)addKeyManagement
{
    [NSApp endSheet:progressSheet];
    [progressSheet orderOut:self];
    
    [progressIndicator stopAnimation:self];
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Unable to generate key pair"];
    [alert setInformativeText:[NSString stringWithFormat:@"%@\n\nThis is most likely a temporary error, please try again later.", [addKeyManagement.error localizedDescription]]];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[self.windowController window]
                      modalDelegate:nil
                     didEndSelector:NULL
                        contextInfo:nil];
}

- (void)gotoTimeMachineView
{
    [NSApp endSheet:progressSheet];
    [progressSheet orderOut:self];
    
    [progressIndicator stopAnimation:self];
    
    [(ADDMainWindowController *)self.windowController changeViewController:ADDViewControllerInfoView];
}
        
- (void)submitToServer
{
    self.addRequest = [[[ADDServerRequestJSON alloc] init] autorelease];
    self.addRequest.delegate = self;
        
    NSString *pubKey = [NSString stringWithContentsOfFile:self.keyMgmt.publicKeyFilePath 
                                                 encoding:NSASCIIStringEncoding 
                                                    error:nil];
    
    NSString *uuidString = @"";
    uuid_t uuid;
    const struct timespec waitTimespec = { 0, 0 };
    if (gethostuuid(uuid, &waitTimespec) == 0)
    {
        uuidString = [NSString stringWithFormat:@"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                      uuid[0], uuid[1], uuid[2], uuid[3], uuid[4], uuid[5], uuid[6], uuid[7], uuid[8], uuid[9], uuid[10], uuid[11], uuid[12], uuid[13], uuid[14], uuid[15]];
    }
    
    NSString *computerName = [(NSString *)SCDynamicStoreCopyComputerName(NULL, NULL) autorelease];
    if (!computerName)
        computerName = @"Computer Name Not Found";
    
    // the OS Version used here is a human string that requires parsing at server end
    // there isn't a good way to get the 10.x part programatically from what I can see...
    NSDictionary *userDetails = [NSDictionary dictionaryWithObjectsAndKeys:
                                 username, ADDServerRequestUsernameFieldName,
                                 password, ADDServerRequestPasswordFieldName,
                                 ADDPrimaryMacAddress(), ADDServerRequestMacAddressFieldName,
                                 [[NSProcessInfo processInfo] operatingSystemVersionString], ADDServerRequestOSVersionFieldName,
                                 pubKey, ADDServerRequestPublicKeyFieldName,
                                 uuidString, ADDServerRequestUUIDFieldName,
                                 (NSString *)computerName, ADDServerRequestComputerNameFieldName,
                                 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], ADDServerRequestAppVersionFieldName,
                                 nil];
    
    [self.addRequest sendUserDetails:userDetails];
}

- (void)requestFailedTemporarily:(ADDServerRequestJSON *)request
{
    [NSApp endSheet:progressSheet];
    [progressSheet orderOut:self];
    
    [progressIndicator stopAnimation:self];
    
    if (request == self.addRequest)
    {
        NSInteger errorCode = [[request error] code];
        
        self.addRequest = nil;
        
        NSString *title;
        NSString *body;
        
        if (errorCode == 403)
        {
            title = @"Authentication error";
            body = @"Your username or password was not recognized";
            
            NSRange at = [username rangeOfString:@"@"];
            if (at.location != NSNotFound)
            {
                body = @"You seem to have entered an email address for your username. Please enter your Dolly Drive account name and password";
            }
            
            // since we know it's an incorrect password...
            self.password = nil;
            [ADDKeyChainManagement removeDollyPasswordInKeychainForUsername:self.username];
        }
        else 
        {
            title = @"Server connection failed";
            body  = [NSString stringWithFormat:@"%@\n\nThis is most likely a temporary error, please try again later.", [request.error localizedDescription]];
        }
        
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:title];
        [alert setInformativeText:body];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
    }
    else 
    {
        // somehow there is another request going on
        [request release];
    }
}

- (void)requestCompleted:(ADDServerRequestJSON *)request withConfig:(ADDServerConfig *)serverConfig
{    
    //TODO: refactor! this is convoluted and contains things that should't be in a controller...
    
    if (request == self.addRequest)
    {
        if (request.requestType == ADDServerRequestTypeSendUserDetails)
        {
            self.addRequest = nil;
            
            serverConfig.afpPassword = self.password;
            serverConfig.afpUsername = self.username;
        
            [ADDAppConfig sharedAppConfig].serverConfig = serverConfig;
        
            if (![serverConfig saveToFile])
            {
                [NSApp endSheet:progressSheet];
                [progressSheet orderOut:self];
                
                [progressIndicator stopAnimation:self];
                
                NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Unable to save config file"];
                [alert setInformativeText:@"There was an error saving the config file to ~/Library/Application Support/DollyDrive"];
                [alert setAlertStyle:NSWarningAlertStyle];
                
                [alert beginSheetModalForWindow:[self.windowController window]
                                  modalDelegate:nil
                                 didEndSelector:NULL
                                    contextInfo:nil];
                
                return;
            }
        
            if (![serverConfig.sparseBundleCreated boolValue])
            {
                // user's sparse bundle isn't created
                self.addRequest = [[[ADDServerRequestJSON alloc] init] autorelease];
                self.addRequest.delegate = self;
                
                self.progressSheetLabel = NSLocalizedString(@"PreparingTMVolumeTitle", nil);
                
                [self.addRequest createSparseBundleWithPassword:self.password];
                
                return;
            }
        }
                        
        if ([[ADDAppConfig sharedAppConfig] helperIsRequired])
        {
            self.progressSheetLabel = @"Running configuration helper";
            [self performSelector:@selector(runHelper) withObject:nil afterDelay:0.1];
        }
        else 
        {
            [self performSelector:@selector(gotoTimeMachineView) withObject:nil afterDelay:0.1];
        }
        
        //[[ADDAppConfig sharedAppConfig] runThrottleHelper];
        
    }
    else 
    {
        // somehow there is another request going on
        [request release];
    }
    
}

- (void)runHelper
{
    // Run DollyDriveHelper which will:
    //   * install wrapper (not done yet)
    //   * add entry to /etc/services if required
    //   * create or replace all users launchd entry
    //   * add or replace keychain entry
    if (![[ADDAppConfig sharedAppConfig] runHelper])
    {
        [NSApp endSheet:progressSheet];
        [progressSheet orderOut:self];
            
        [progressIndicator stopAnimation:self];
            
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Error reported by config helper"];
        [alert setInformativeText:[[ADDAppConfig sharedAppConfig].error localizedDescription]];
        [alert setAlertStyle:NSWarningAlertStyle];
            
        [alert beginSheetModalForWindow:[self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
            
        return;
    }
    
    [self performSelector:@selector(gotoTimeMachineView) withObject:nil afterDelay:0.1];
}

- (void)dealloc
{
    [keyMgmt release];
    keyMgmt = nil;
    [username release];
    username = nil;
    [password release];
    password = nil;
    [progressSheetLabel release];
    progressSheetLabel = nil;
    
    [super dealloc];
}

@end
