//
//  UKCrashReporter.m
//  NiftyFeatures
//
//  Created by Uli Kusterer on Sat Feb 04 2006.
//  Copyright (c) 2006 M. Uli Kusterer. All rights reserved.
//

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import "UKCrashReporter.h"
#import "UKSystemInfo.h"
#import <AddressBook/AddressBook.h>

#import "ADDLogReporter.h"
#import "ADDAppConfig.h"
#import "ASIHTTPRequest.h"
#import "YAJL.h"

#define ADDFeedbackVCTenderURLString @"https://api.tenderapp.com/dollydrive/categories/34480/discussions"
#define ADDFeedbackVCTenderAuthHeaderKey @"X-Tender-Auth"
//TODO: obfuscate
#define ADDFeedbackVCTenderAuthHeaderVal @"5ec6ab86375f251de54fd0a6dc3ac916f05edafa"


NSString*	UKCrashReporterFindTenFiveCrashReportPath( NSString* appName, NSString* crashLogsFolder );

// -----------------------------------------------------------------------------
//	UKCrashReporterCheckForCrash:
//		This submits the crash report to a CGI form as a POST request by
//		passing it as the request variable "crashlog".
//	
//		KNOWN LIMITATION:	If the app crashes several times in a row, only the
//							last crash report will be sent because this doesn't
//							walk through the log files to try and determine the
//							dates of all reports.
//
//		This is written so it works back to OS X 10.2, or at least gracefully
//		fails by just doing nothing on such older OSs. This also should never
//		throw exceptions or anything on failure. This is an additional service
//		for the developer and *mustn't* interfere with regular operation of the
//		application.
// -----------------------------------------------------------------------------

BOOL	UKCrashReporterCheckForCrash()
{
	NSAutoreleasePool*	pool = [[NSAutoreleasePool alloc] init];
    
    BOOL didCrash = NO;
	
	NS_DURING
		// Try whether the classes we need to talk to the CGI are present:
		Class			NSMutableURLRequestClass = NSClassFromString( @"NSMutableURLRequest" );
		Class			NSURLConnectionClass = NSClassFromString( @"NSURLConnection" );
		if( NSMutableURLRequestClass == Nil || NSURLConnectionClass == Nil )
		{
			[pool release];
			return NO;
		}
		
		long	sysvMajor = 0, sysvMinor = 0, sysvBugfix = 0;
		UKGetSystemVersionComponents( &sysvMajor, &sysvMinor, &sysvBugfix );
		BOOL	isTenFiveOrBetter = sysvMajor >= 10 && sysvMinor >= 5;
		
		// Get the log file, its last change date and last report date:
		NSString*		appName = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleExecutable"];
		NSString*		crashLogsFolder = [@"~/Library/Logs/CrashReporter/" stringByExpandingTildeInPath];
		NSString*		crashLogName = [appName stringByAppendingString: @".crash.log"];
		NSString*		crashLogPath = nil;
		if( !isTenFiveOrBetter )
			crashLogPath = [crashLogsFolder stringByAppendingPathComponent: crashLogName];
		else
			crashLogPath = UKCrashReporterFindTenFiveCrashReportPath( appName, crashLogsFolder );
    NSDictionary*	fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:crashLogPath error:nil];
		NSDate*			lastTimeCrashLogged = (fileAttrs == nil) ? nil : [fileAttrs fileModificationDate];
		NSTimeInterval	lastCrashReportInterval = [[NSUserDefaults standardUserDefaults] floatForKey: @"UKCrashReporterLastCrashReportDate"];
		NSDate*			lastTimeCrashReported = [NSDate dateWithTimeIntervalSince1970: lastCrashReportInterval];
		
		if( lastTimeCrashLogged )	// We have a crash log file and its mod date? Means we crashed sometime in the past.
		{
			// If we never before reported a crash or the last report lies before the last crash:
			if( [lastTimeCrashReported compare: lastTimeCrashLogged] == NSOrderedAscending )
			{
				// Fetch the newest report from the log:
				NSString*			crashLog = [NSString stringWithContentsOfFile:crashLogPath encoding:NSASCIIStringEncoding error:NULL];
				NSArray*			separateReports = [crashLog componentsSeparatedByString: @"\n\n**********\n\n"];
				NSString*			currentReport = [separateReports count] > 0 ? [separateReports objectAtIndex: [separateReports count] -1] : @"*** Couldn't read Report ***";	// 1 since report 0 is empty (file has a delimiter at the top).
				unsigned			numCores = UKCountCores();
				NSString*			numCPUsString = (numCores == 1) ? @"" : [NSString stringWithFormat: @"%dx ",numCores];
                
                
                currentReport = [NSString stringWithFormat:@"\t%@", [currentReport stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
                
                NSString *defaultsString = [[[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] description];
                defaultsString = [NSString stringWithFormat:@"\t%@", [defaultsString stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
                

                				
				// Create a string containing Mac and CPU info, crash log and prefs:
				currentReport = [NSString stringWithFormat:
                                 @"Model: %@\nCPU Speed: %@%.2f GHz\n%@\n\nPreferences:\n%@",
                                 UKMachineName(), numCPUsString, ((float)UKClockSpeed()) / 1000.0f,
                                 currentReport,
                                 defaultsString
                                 ];
				
				// Now show a crash reporter window so the user can edit the info to send:
				[[UKCrashReporter alloc] initWithLogString: currentReport];
                
                didCrash = YES;
			}
		}
	NS_HANDLER
		NSLog(@"Error during check for crash: %@",localException);
	NS_ENDHANDLER
	
	[pool release];
    
    return didCrash;
}

NSString*	UKCrashReporterFindTenFiveCrashReportPath( NSString* appName, NSString* crashLogsFolder )
{
	NSDirectoryEnumerator*	enny = [[NSFileManager defaultManager] enumeratorAtPath: crashLogsFolder];
	NSString*				currName = nil;
	NSString*				crashLogPrefix = [NSString stringWithFormat: @"%@_",appName];
	NSString*				crashLogSuffix = @".crash";
	NSString*				foundName = nil;
	NSDate*					foundDate = nil;
	
	// Find the newest of our crash log files:
	while(( currName = [enny nextObject] ))
	{
		if( [currName hasPrefix: crashLogPrefix] && [currName hasSuffix: crashLogSuffix] )
		{
			NSDate*	currDate = [[enny fileAttributes] fileModificationDate];
			if( foundName )
			{
				if( [currDate isGreaterThan: foundDate] )
				{
					foundName = currName;
					foundDate = currDate;
				}
			}
			else
			{
				foundName = currName;
				foundDate = currDate;
			}
		}
	}
	
	if( !foundName )
		return nil;
	else
		return [crashLogsFolder stringByAppendingPathComponent: foundName];
}


NSString*	gCrashLogString = nil;


@implementation UKCrashReporter

-(id)	initWithLogString: (NSString*)theLog
{
	// In super init the awakeFromNib method gets called, so we can not
	//	use ivars to transfer the log, and use a global instead:
	gCrashLogString = [theLog retain];
	
	self = [super init];
	return self;
}


-(id)	init
{
	self = [super init];
	if( self )
	{
		feedbackMode = YES;
	}
	return self;
}


-(void) dealloc
{
	[connection release];
	connection = nil;
	
	[super dealloc];
}


-(void)	awakeFromNib
{
    // popuulate from dolly drive config if possible
    
    @try {
        if ([ADDServerConfig configFileExists])
        {
            ADDServerConfig *serverConfig = [[ADDServerConfig alloc] initFromFile];
            
            //[emailAddressField setStringValue:serverConfig.email]; // don't have this yet
            [usernameField setStringValue:serverConfig.afpUsername];
        }
    }
    @catch (NSException * e) {
        NSLog(@"exception while getting dolly drive prefs: %@", e);
    }
    
	// Insert the app name into the explanation message:
	NSString*			appName = [[NSFileManager defaultManager] displayNameAtPath: [[NSBundle mainBundle] bundlePath]];
	NSMutableString*	expl = nil;
	if( gCrashLogString )
		expl = [[[explanationField stringValue] mutableCopy] autorelease];
	else
		expl = [[NSLocalizedStringFromTable(@"FEEDBACK_EXPLANATION_TEXT",@"UKCrashReporter",@"") mutableCopy] autorelease];
	[expl replaceOccurrencesOfString: @"%%APPNAME" withString: appName
				options: 0 range: NSMakeRange(0, [expl length])];
	[explanationField setStringValue: expl];
	
	// Insert user name and e-mail address into the information field:
	NSMutableString*	userMessage = nil;
	if( gCrashLogString )
		userMessage = [[[informationField string] mutableCopy] autorelease];
	else
		userMessage = [[NSLocalizedStringFromTable(@"FEEDBACK_MESSAGE_TEXT",@"UKCrashReporter",@"") mutableCopy] autorelease];
	[userMessage replaceOccurrencesOfString: @"%%LONGUSERNAME" withString: NSFullUserName()
				options: 0 range: NSMakeRange(0, [userMessage length])];
	ABMultiValue*	emailAddresses = [[[ABAddressBook sharedAddressBook] me] valueForProperty: kABEmailProperty];
	NSString*		emailAddr = NSLocalizedStringFromTable(@"MISSING_EMAIL_ADDRESS",@"UKCrashReporter",@"");
	if( emailAddresses )
	{
		NSString*		defaultKey = [emailAddresses primaryIdentifier];
		if( defaultKey )
		{
			NSUInteger	defaultIndex = [emailAddresses indexForIdentifier: defaultKey];
            emailAddr = [emailAddresses valueAtIndex: defaultIndex];
		}
	}
	[userMessage replaceOccurrencesOfString: @"%%EMAILADDRESS" withString: emailAddr
				options: 0 range: NSMakeRange(0, [userMessage length])];
        
	[informationField setString: userMessage];
	
	// Show the crash log to the user:
	if( gCrashLogString )
	{
		[crashLogField setString: gCrashLogString];
		[gCrashLogString release];
		gCrashLogString = nil;
	}
	else
	{
		[remindButton setHidden: YES];
		
		NSInteger		itemIndex = [switchTabView indexOfTabViewItemWithIdentifier: @"de.zathras.ukcrashreporter.crashlog-tab"];
		NSTabViewItem*	crashLogItem = [switchTabView tabViewItemAtIndex: itemIndex];
		unsigned		numCores = UKCountCores();
		NSString*		numCPUsString = (numCores == 1) ? @"" : [NSString stringWithFormat: @"%dx ",numCores];
		[crashLogItem setLabel: NSLocalizedStringFromTable(@"SYSTEM_INFO_TAB_NAME",@"UKCrashReporter",@"")];
		
		NSString*	systemInfo = [NSString stringWithFormat: @"Application: %@ %@\nModel: %@\nCPU Speed: %@%.2f GHz\nSystem Version: %@\n\nPreferences:\n%@",
									appName, [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"],
									UKMachineName(), numCPUsString, ((float)UKClockSpeed()) / 1000.0f,
									UKSystemVersionString(),
									[[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]]];
		[crashLogField setString: systemInfo];
	}
	
	// Show the window:
	[reportWindow makeKeyAndOrderFront: self];
}


-(IBAction)	sendCrashReport: (id)sender
{
    NSString *email = [emailAddressField stringValue];
    NSString *username = [usernameField stringValue];
    
    if (!email || !username || [email isEqualToString:@""] || [username isEqualToString:@""])
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Missing information"];
        [alert setInformativeText:@"You must enter both your email address and username."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:reportWindow
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
        return;
    }
    
    // Dolly Drive extras
    
    ADDLogReporter *addLog = [[[ADDLogReporter alloc] init] autorelease];
    NSString *dollyText = [addLog allDollyLogs];
    
	NSString            *boundary = @"0xKhTmLbOuNdArY";
	NSMutableString*	crashReportString = [NSMutableString string];
	[crashReportString appendString: [informationField string]];
	[crashReportString appendString: @"\n==========\n"];
	[crashReportString appendString: [crashLogField string]];
	[crashReportString replaceOccurrencesOfString: boundary withString: @"USED_TO_BE_KHTMLBOUNDARY" options: 0 range: NSMakeRange(0, [crashReportString length])];
    
    [crashReportString appendString:@"\n\n"];
    [crashReportString appendString:dollyText];
    
    NSDictionary *extras = [NSDictionary dictionaryWithObjectsAndKeys:
                            username, @"dolly_drive_username",
                            nil];
    
    NSDictionary *reqDict = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSString stringWithFormat:@"Crash report for %@", username], @"title",
                             [NSNumber numberWithBool:NO], @"public",
                             email, @"author_email",
                             username, @"author_name",
                             crashReportString, @"body",
                             [NSNumber numberWithBool:YES], @"skip_spam",
                             extras, @"extras",
                             nil];
    
    ASIHTTPRequest *req = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:ADDFeedbackVCTenderURLString]];
    [req addRequestHeader:ADDFeedbackVCTenderAuthHeaderKey value:ADDFeedbackVCTenderAuthHeaderVal];
    [req addRequestHeader:@"Accept" value:@"application/json"];
    [req addRequestHeader:@"Content-Type" value:@"application/json"];
    [req setRequestMethod:@"POST"];
    //req.shouldCompressRequestBody = YES; - tender doesn't support compression

    [req appendPostData:[[reqDict yajl_JSONString] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [req setDelegate:self];
    
    
	// Go into progress mode and kick off the HTTP post:
	[progressIndicator startAnimation: self];
	[sendButton setEnabled: NO];
	[remindButton setEnabled: NO];
	[discardButton setEnabled: NO];
	
    [req startAsynchronous];
}


-(IBAction)	remindMeLater: (id)sender
{
	[reportWindow orderOut: self];
}


-(IBAction)	discardCrashReport: (id)sender
{
	// Remember we already did this crash, so we don't ask twice:
	if( !feedbackMode )
	{
		[[NSUserDefaults standardUserDefaults] setFloat: [[NSDate date] timeIntervalSince1970] forKey: @"UKCrashReporterLastCrashReportDate"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	[reportWindow orderOut: self];
}


-(void)	showFinishedMessage: (NSString*)errMsg
{
	if( errMsg )
	{
		NSString*		errTitle = nil;
		if( feedbackMode )
			errTitle = NSLocalizedStringFromTable( @"COULDNT_SEND_FEEDBACK_ERROR",@"UKCrashReporter",@"");
		else
			errTitle = NSLocalizedStringFromTable( @"COULDNT_SEND_CRASH_REPORT_ERROR",@"UKCrashReporter",@"");
		
		NSRunAlertPanel( errTitle, @"%@", NSLocalizedStringFromTable( @"COULDNT_SEND_CRASH_REPORT_ERROR_OK",@"UKCrashReporter",@""), @"", @"",
						 errMsg );
	}
	
	[reportWindow orderOut: self];
	[self autorelease];
}


- (void)requestFinished:(ASIHTTPRequest *)request
{
    if ([request responseStatusCode] != 201)
        [self performSelectorOnMainThread: @selector(showFinishedMessage:) withObject:[request responseStatusMessage] waitUntilDone: NO];
        
	// Now that we successfully sent this crash, don't report it again:
	if( !feedbackMode )
	{
		[[NSUserDefaults standardUserDefaults] setFloat: [[NSDate date] timeIntervalSince1970] forKey: @"UKCrashReporterLastCrashReportDate"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	[self performSelectorOnMainThread: @selector(showFinishedMessage:) withObject: nil waitUntilDone: NO];
}


- (void)requestFailed:(ASIHTTPRequest *)request
{
	[self performSelectorOnMainThread: @selector(showFinishedMessage:) withObject:[request error] waitUntilDone: NO];
}

@end


@implementation UKFeedbackProvider

-(IBAction) orderFrontFeedbackWindow: (id)sender
{
#ifndef __clang_analyzer__
	[[UKCrashReporter alloc] init];
#endif
}


-(IBAction) orderFrontBugReportWindow: (id)sender
{
#ifndef __clang_analyzer__
	[[UKCrashReporter alloc] init];
#endif
}

@end
