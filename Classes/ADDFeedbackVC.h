//
//  ADDFeedbackVC.h
//  DollyDriveApp
//
//  Created by Mark Aufflick on 13/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MGAViewController.h"

@interface ADDFeedbackVC : MGAViewController
{
    NSString *email;
    NSString *name;
    NSString *username;
    NSString *subject;
    NSString *comments;    
}

@property (retain) NSString *email;
@property (retain) NSString *name;
@property (retain) NSString *username;
@property (retain) NSString *subject;
@property (retain) NSString *comments;

- (IBAction)send:(id)sender;

@end
