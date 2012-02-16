//
//  AccountViewController.h
//  DollyDriveApp
//
//  Created by Angelone John on 10/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//
#import "MGAViewController.h"
#import <Cocoa/Cocoa.h>

@interface AccountViewController : MGAViewController
{
   NSString *username;   
    IBOutlet NSTabView *tabview;
}

@property (copy) NSString *username;
@property (retain)  NSTabView *tabview;

- (IBAction)restoreTMPlist:(id)sender;
- (IBAction)changeUser:(id)sender;
- (IBAction)accountDetails:(id)sender;

- (NSView*)tabView;

@end
