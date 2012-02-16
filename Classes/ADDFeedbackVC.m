//
//  ADDFeedbackVC.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 13/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDFeedbackVC.h"

#import "ADDLogReporter.h"
#import "ASIFormDataRequest.h"
#import "ADDAppConfig.h"
#import "YAJL.h"

#define ADDFeedbackVCTenderURLString @"https://api.tenderapp.com/dollydrive/categories/34480/discussions"
#define ADDFeedbackVCTenderAuthHeaderKey @"X-Tender-Auth"
//TODO: obfuscate
#define ADDFeedbackVCTenderAuthHeaderVal @"5ec6ab86375f251de54fd0a6dc3ac916f05edafa"

@implementation ADDFeedbackVC

@synthesize email;
@synthesize name;
@synthesize username;
@synthesize subject;
@synthesize comments;

- (void)windowWillShow
{
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    ADDServerConfig *serverConfig = [appConfig serverConfig];
    if (!serverConfig && [ADDServerConfig configFileExists])
        serverConfig = [[[ADDServerConfig alloc] initFromFile] autorelease];
    
    if (serverConfig)
    {
        self.username = serverConfig.afpUsername;
        //TODO: name and email when Alan puts them in the API
    }
}

- (IBAction)send:(id)sender
{
    ASIHTTPRequest *req = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:ADDFeedbackVCTenderURLString]];
    [req addRequestHeader:ADDFeedbackVCTenderAuthHeaderKey value:ADDFeedbackVCTenderAuthHeaderVal];
    [req addRequestHeader:@"Accept" value:@"application/json"];
    [req addRequestHeader:@"Content-Type" value:@"application/json"];
    [req setRequestMethod:@"POST"];
    //req.shouldCompressRequestBody = YES; - tender doesn't support compression
    
    //TODO: check values are there
    
    ADDLogReporter *addLog = [[[ADDLogReporter alloc] init] autorelease];
    NSString *logs = [addLog allDollyLogs];
    
    NSString *body = [NSString stringWithFormat:@"User comment\n============\n\n%@\n\n%@",
                      self.comments, logs];
    
    NSDictionary *extras = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.username, @"dolly_drive_username",
                            nil];
    
    NSDictionary *reqDict = [NSDictionary dictionaryWithObjectsAndKeys:
                             self.subject, @"title",
                             [NSNumber numberWithBool:NO], @"public",
                             self.email, @"author_email",
                             self.name, @"author_name",
                             body, @"body",
                             [NSNumber numberWithBool:YES], @"skip_spam",
                             extras, @"extras",
                             nil];
    
    [req appendPostData:[[reqDict yajl_JSONString] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // TODO - asunc and display sheet with indeterminate progress bar
    [req startSynchronous];
    
    NSError *error = [req error];
    if (error || [req responseStatusCode] != 201)
    {
        NSLog(@"error code: %d sending feedback: %@ response: %@", [req responseStatusCode], error, [req responseString]);
        
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Sending Feedback Failed"];
        [alert setInformativeText:@"Please make sure you have filled in all the fields and that you have an active Internet connection."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
    }
    else 
    {
        NSLog(@"success sending feedback");
        [self.windowController close];
    }
}


@end
