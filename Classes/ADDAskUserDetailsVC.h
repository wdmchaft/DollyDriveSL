//
//  ADDAskUserDetailsView.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MGAViewController.h"

#import "ADDServerRequestJSON.h"
#import "ADDServerConfig.h"
#import "ADDKeyManagement.h"
#import "ADDClickableTextField.h"

@interface ADDAskUserDetailsVC : MGAViewController <NSTextFieldDelegate, ADDServerRequestDelegate, ADDKeyManagementDelegate>
{
    NSString *username;
    NSString *password;
    
    NSString *progressSheetLabel;
    
    ADDServerRequestJSON *addRequest;
    ADDKeyManagement *keyMgmt;
    
    IBOutlet NSPanel *progressSheet;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSSecureTextField *passwordField;
    IBOutlet ADDClickableTextField *forgottenPasswordField;
    IBOutlet NSButton *loginButton;
}

@property (retain) NSString *username;
@property (retain) NSString *password;
@property (retain) ADDServerRequestJSON *addRequest;
@property (retain) ADDKeyManagement *keyMgmt;
@property (retain) NSString *progressSheetLabel;

- (IBAction)submit:(id)sender;

@end
