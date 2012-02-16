//
//  HelperClass.m
//  DollyDriveClone
//
//  Created by John Angelone on 6/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CopyHelperClass.h"

#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>


#define ADDHelperExecutableName "DollyClone Helper"
#define ADDSupportDirectorySuffix @"DollyCloneScheduler"


static int CopyFileOverwriting(const char *sourcePath, mode_t destMode, const char *destPath);


@implementation CopyHelperClass

@synthesize supportDirectory;
@synthesize error;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(
                                                            NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES
                                                            );
        
        
        NSDictionary *dirAttribs = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:0775], NSFilePosixPermissions,
                                    nil];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSError *error = NULL;
        
        
        [self setValue:@"/Library/Application Support/DollyClone"
                forKey:@"supportDirectory"];  
        
        
        if(![fileManager createDirectoryAtPath:self.supportDirectory withIntermediateDirectories:YES attributes:dirAttribs error:&error])
            NSLog(@"Error: Create folder failed for %@ - error:%@", self.supportDirectory, error);
        
    }
    
    return self;
}

- (NSString *)copyHelperPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"CloneVolume Helper"];
}

- (NSString *)copyHelperSourcePath
{
    return [[NSBundle mainBundle] pathForResource:@"CloneVolume Helper" ofType:nil];
}

- (NSString *)schedulerPath
{
    return [self.supportDirectory stringByAppendingPathComponent:@"DollyScheduler"];
}

- (NSString *)schedulerSourcePath
{
    return [[NSBundle mainBundle] pathForResource:@"DollyScheduler" ofType:nil];
}


- (BOOL)copyHelperMatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:self.copyHelperPath isDirectory:&isDirectory];
    if (!exists || isDirectory)
        return NO;
    
    if (![fm contentsEqualAtPath:self.copyHelperPath andPath:self.copyHelperSourcePath])
        return NO;
    
    error = nil;
    NSDictionary *attributes = [fm attributesOfItemAtPath:self.copyHelperPath error:&error];
    if (
        error ||
        [attributes filePosixPermissions] != 04555 ||
        ![[attributes fileOwnerAccountName] isEqualToString:@"root"]
        )
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)schedulerMatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:self.schedulerPath isDirectory:&isDirectory];
    if (!exists || isDirectory)
        return NO;
    
    if (![fm contentsEqualAtPath:self.schedulerPath andPath:self.schedulerSourcePath])
        return NO;
    
    error = nil;
    NSDictionary *attributes = [fm attributesOfItemAtPath:self.schedulerPath error:&error];
    if (
        error ||
        [attributes filePosixPermissions] != 04555 ||
        ![[attributes fileOwnerAccountName] isEqualToString:@"root"]
        )
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)copyHelper
{
    // copy & set setuid
    int err = CopyFileOverwriting(
                                  [self.copyHelperSourcePath UTF8String], //const char *sourcePath, 
                                  04555, //mode_t destMode, 
                                  [self.copyHelperPath UTF8String] //const char *destPath
                                  );
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to copy helper: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    err = chmod([self.copyHelperPath UTF8String], 04555);
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to chmod copy helper: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
    }
    
    return YES;
    
}

- (BOOL)copyScheduler
{
    // copy & set setuid
    int err = CopyFileOverwriting(
                                  [self.schedulerSourcePath UTF8String], //const char *sourcePath, 
                                  04555, //mode_t destMode, 
                                  [self.schedulerPath UTF8String] //const char *destPath
                                  );
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to copy scheduler: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
        
        return NO;
    }
    
    err = chmod([self.schedulerPath UTF8String], 04555);
    
    if (err != 0)
    {
        self.error = [NSError errorWithDomain:[NSString stringWithFormat:@"Unable to chmod copy scheduler: %s", strerror(err)]
                                         code:err 
                                     userInfo:nil];
    }
    
    
}


- (BOOL)helperIsRequired
{
    if (![self copyHelperMatches] || ![self schedulerMatches])
        return YES;
    else
        return NO;
}

- (BOOL)schedulerIsRequired
{
    if (![self schedulerMatches])
        return YES;
    else
        return NO;
}
- (void)dealloc
{
    [super dealloc];
}

//TODO: AARRGGHH - copy/paste!!
static int CopyFileOverwriting(
                               const char					*sourcePath, 
                               mode_t						destMode, 
                               const char					*destPath
                               )
// Our own version of a file copy. This routine will either handle
// the copy of the tool binary or the plist file associated with
// that binary. As the function name suggests, it writes over any 
// existing file pointed to by (const char *) destPath.
{
	int			err;
	int			junk;
	int			sourceFD;
	int			destFD;
	char		buf[65536];
    
	// Pre-conditions.
	assert(sourcePath != NULL);
	assert(destPath != NULL);
    
    (void) unlink(destPath);
    
	destFD = -1;
    
	err = 0;
	sourceFD = open(sourcePath, O_RDONLY);
	if (sourceFD < 0) {
		err = errno;
	}           
    
	if (err == 0) {
		destFD = open(destPath, O_CREAT | O_EXCL | O_WRONLY, destMode);
		if (destFD < 0) {
			err = errno;
		}
	}
    
	if (err == 0) {
		ssize_t	bytesReadThisTime;
		ssize_t	bytesWrittenThisTime;
		ssize_t	bytesWritten;
        
		do {
			bytesReadThisTime = read(sourceFD, buf, sizeof(buf));
			if (bytesReadThisTime < 0) {
				err = errno;
			}
            
			bytesWritten = 0;
			while ( (err == 0) && (bytesWritten < bytesReadThisTime) ) {
				bytesWrittenThisTime = write(destFD, &buf[bytesWritten], bytesReadThisTime - bytesWritten);
				if (bytesWrittenThisTime < 0) {
					err = errno;
				} else {
					bytesWritten += bytesWrittenThisTime;
				}
			}
            
		} while ( (err == 0) && (bytesReadThisTime != 0) );
	}
    
	// Clean up.
    
	if (sourceFD != -1) {
		junk = close(sourceFD);
		assert(junk == 0);
	}
	if (destFD != -1) {
		junk = close(destFD);
		assert(junk == 0);
	}
    
#ifdef DEBUG
    fprintf(stderr, "copy '%s' %#o '%s' -> %d\n", sourcePath, (int) destMode, destPath, err);
#endif
    
	return err;
}



@end
