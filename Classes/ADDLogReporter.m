//
//  ADDLogReporter.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 13/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDLogReporter.h"

#import <asl.h>

@implementation ADDLogReporter

- (NSString*)gatherConsoleLogViaAppleSystemLoggerFromDate:(NSDate*)date forField:(const char *)field regex:(const char *)regex
{
	// asl_* functions only exist on Mac OS X 10.4 (Tiger) onward, so bail out
	// early if the functions don't exist.  (See the #include'd "asl-weak.h"
	// file: it's the same as /usr/include/asl.h, but all functions are
	// defined to be weak-imported.)
	if(asl_new == NULL || asl_set_query == NULL || asl_search == NULL
	   || aslresponse_next == NULL || asl_get == NULL
	   || aslresponse_free == NULL)
	{
		return nil;
	}
	
	aslmsg query = asl_new(ASL_TYPE_QUERY);
	if(query == NULL) return nil;
	
	const uint32_t senderQueryOptions = ASL_QUERY_OP_EQUAL|ASL_QUERY_OP_REGEX;
	const int aslSetSenderQueryReturnCode = asl_set_query(query, field, regex, senderQueryOptions);
	if(aslSetSenderQueryReturnCode != 0) return nil;
	
	static const size_t timeBufferLength = 64;
	char oneHourAgo[timeBufferLength];
	snprintf(oneHourAgo, timeBufferLength, "%0lf", [date timeIntervalSince1970]);
	const int aslSetTimeQueryReturnCode = asl_set_query(query, ASL_KEY_TIME, oneHourAgo, ASL_QUERY_OP_GREATER_EQUAL);
	if(aslSetTimeQueryReturnCode != 0) return nil;
	
	aslresponse response = asl_search(NULL, query);
	
	NSMutableString* searchResults = [NSMutableString string];
	for(;;)
	{
		aslmsg message = aslresponse_next(response);
		if(message == NULL)
            break;
        
        // todo : add sender
        const char *sender = asl_get(message, ASL_KEY_SENDER);
        if (sender == NULL)
            continue;
		
		const char* logTime = asl_get(message, ASL_KEY_TIME);
		if(logTime == NULL)
            continue;
		
		const char* level = asl_get(message, ASL_KEY_LEVEL);
		if(level == NULL)
            continue;
		
		const char* messageText = asl_get(message, ASL_KEY_MSG);
		if(messageText == NULL)
            continue;
		
		NSCalendarDate* logDate = [NSCalendarDate dateWithTimeIntervalSince1970:atof(logTime)];
        
        // hack for Mark
        if (strlen(messageText) > 1000)
            continue;
		
		[searchResults appendFormat:@"%s - %@[%s]: %s\n", sender, [logDate description], level, messageText];
	}
	
	aslresponse_free(response);
	
	return searchResults;
}

- (NSString *)allDollyLogs
{
    NSDate *history = [NSDate dateWithTimeIntervalSinceNow:-(24*60*60)];
    
    NSString *mainLog = [self gatherConsoleLogViaAppleSystemLoggerFromDate:history
                                                                  forField:ASL_KEY_SENDER
                                                                     regex:".*([Dd][Oo][Ll][Ll][Yy].?[Dd][Rr][Ii][Vv][Ee]|backupd)"];
    
    NSString *afpLog = [self gatherConsoleLogViaAppleSystemLoggerFromDate:history
                                                                 forField:ASL_KEY_MSG
                                                                    regex:"^AFP.*[Dd][Oo][Ll][Ll][Yy]"];
    
    NSString *cloneLog = [self gatherConsoleLogViaAppleSystemLoggerFromDate:history
                                                                   forField:ASL_KEY_MSG
                                                                      regex:"CloneVolume Helper"];

    // add tabs for markdown
    mainLog = [NSString stringWithFormat:@"\t%@", [mainLog stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    afpLog = [NSString stringWithFormat:@"\t%@", [afpLog stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    cloneLog = [NSString stringWithFormat:@"\t%@", [cloneLog stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];

    NSString *body = [NSString stringWithFormat:@"Main Log\n=======\n\n%@"
                      "\n\nAFP Log\n=======\n\n%@"
                      "\n\nClone Log\n=======\n\n%@",
                      mainLog, afpLog, cloneLog];
    
    return body;
}


@end
