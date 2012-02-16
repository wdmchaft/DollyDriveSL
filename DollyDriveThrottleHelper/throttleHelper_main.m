#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <unistd.h>


#define BUFSIZE 512

CFPropertyListRef configCreateFromFile(const char *configPath) {
	CFStringRef configString;
	CFURLRef configURL;
	Boolean status;
	CFDataRef configData;
	SInt32 errorCode;
    CFStringRef errorString = NULL;
	CFPropertyListRef configPlist = NULL;
    
	configString = CFStringCreateWithCStringNoCopy(
                                                   kCFAllocatorDefault,
                                                   configPath,
                                                   kCFStringEncodingUTF8,
                                                   kCFAllocatorNull);
	//TODO: die if configPath == NULL
	configURL = CFURLCreateWithFileSystemPath(
                                              kCFAllocatorDefault,
                                              configString,
                                              kCFURLPOSIXPathStyle,
                                              false);
	status = CFURLCreateDataAndPropertiesFromResource(
                                                      kCFAllocatorDefault,
                                                      configURL,
                                                      &configData,
                                                      NULL,
                                                      NULL,
                                                      &errorCode);
	//TODO: check configData is good
    if (!status)
    {
        //NSLog(@"Could not read config file data due to error code %d", (int)errorCode);
    }
    else
    {
        configPlist = CFPropertyListCreateFromXMLData (
                                                       kCFAllocatorDefault, //CFAllocatorRef allocator,
                                                       configData, //CFDataRef xmlData,
                                                       kCFPropertyListImmutable, //CFOptionFlags mutabilityOption,
                                                       &errorString //CFStringRef *errorString
                                                       );
        
        //TODO: check configPlist is good
        // TypeID == CFDictionaryGetTypeID()
        // we have a tunnelServers, which is an array
        // we have a tunnelIdentity, which is a string
        // we have a tunnelArgs, which is an array of strings
        //CFShow(configPlist);
    }
    if (configString != NULL) CFRelease(configString);
    if (configURL != NULL) CFRelease(configURL);
	return configPlist;
}

const char * CStringFromCRef(CFStringRef str)
{
    CFDataRef data = NULL;
    const char *cstring;
    
    cstring = CFStringGetCStringPtr(str, kCFStringEncodingASCII);
    if (cstring == NULL) {
        char localBuffer[10];
        CFStringGetCString(str, localBuffer, 10, kCFStringEncodingASCII);
    }
    
    // A pretty simple solution is to use a CFData; this frees you from guessing at the buffer size
    // But it does allocate a CFData...
    
    data = CFStringCreateExternalRepresentation(NULL, str, kCFStringEncodingASCII, 0);
    if (data) {
        cstring = (const char *)CFDataGetBytePtr(data);
        //CFRelease(data);
    }
    //if (data != NULL) CFRelease(data);
    return cstring;
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
	CFDictionaryRef configDict;
    CFDictionaryRef settingsDict;
    //ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
	//char **sshargv;
    NSString *supportDirectory;
	int ret = 2;
    
    FILE *in;
    char buff[512];

    
    NSString *userPath = [ NSString stringWithUTF8String:argv[1] ] ;
    
     //NSLog(@"Throttler settings user path %@", userPath);
    //NSString *folder = @"~/Library/Application Support/DollyDrive/config";
    NSString *configPath = [[NSString stringWithString:userPath] stringByAppendingPathComponent:@"config"];// [folder stringByExpandingTildeInPath];
    
    //folder = @"~/Library/Application Support/DollyDrive/throttleConfig.plist";
    //NSString *settingsPath = [folder stringByExpanargv[1])dingTildeInPath];
    NSString *settingsPath = [[[NSString stringWithString:userPath] stringByAppendingPathComponent:@"throttleConfig"] stringByAppendingPathExtension:@"plist"];//
       // NSLog(@"Throttler settings plist Path in helper %@", settingsPath);
	//if(argc != 2) {
	//	fprintf(stderr, "usage: %s .../config.plist\n", argv[0]);
	//	exit(1);
	//}
    //CFStringRef dollyPath = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@"), argv[1]);
    //CFStringRef configPath = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@\config"), argv[1]);
    //CFStringRef configPath = CFStringCreateWithFormat(NULL, NULL, CFSTR("%s/config\0"), supportDirectory);
    //CFStringRef settingsPath = CFStringCreateWithFormat(NULL, NULL, CFSTR("%s/throttleConfig.plist\0"), supportDirectory);

    //const char *configFileName = CStringFromCRef(configPath);
    //const char *settingsFileName = CStringFromCRef(settingsPath);
/*
    CFDataRef data;
    
    configFileName = CFStringGetCStringPtr(configPath, kCFStringEncodingASCII);
    if (configFileName == NULL) {
        char localBuffer[10];
        CFStringGetCString(configPath, localBuffer, 10, kCFStringEncodingASCII);
    }
    
    // A pretty simple solution is to use a CFData; this frees you from guessing at the buffer size
    // But it does allocate a CFData...
    
    data = CFStringCreateExternalRepresentation(NULL, configPath, kCFStringEncodingASCII, 0);
    if (data) {
        configFileName = (const char *)CFDataGetBytePtr(data);
    }
    //CFRelease(data);
    
    
    
    settingsFileName = CFStringGetCStringPtr(settingsPath, kCFStringEncodingASCII);
    if (settingsFileName == NULL) {
        char localBuffer[10];
        CFStringGetCString(settingsPath, localBuffer, 10, kCFStringEncodingASCII);
    }
    
    // A pretty simple solution is to use a CFData; this frees you from guessing at the buffer size
    // But it does allocate a CFData...
    
    data = CFStringCreateExternalRepresentation(NULL, settingsPath, kCFStringEncodingASCII, 0);
    if (data) {
        settingsFileName = (const char *)CFDataGetBytePtr(data);
    }/Users/john/Library/Application Support/DollyDrive
    */
    
    configDict = configCreateFromFile([configPath cString]); //configFileName);
    
    //settingsFileName = CFStringGetCStringPtr(settingsPath, kCFStringEncodingUTF8);
    settingsDict = configCreateFromFile([settingsPath cString]); //settingsFileName);
    
	CFArrayRef tunnelServers = CFDictionaryGetValue(configDict, CFSTR("tunnelServers"));
	UInt16 tunnelServerCount = CFArrayGetCount(tunnelServers);
    
	CFStringRef throttleSpeed = CFDictionaryGetValue(settingsDict, CFSTR("speed"));
    
    CFComparisonResult result;
    //result = CFStringCompareWithOptions(throttleSpeed, CFSTR("10241"), CFRangeMake(0,CFStringGetLength(throttleSpeed)), kCFCompareCaseInsensitive);
    //Boolean throttleOn  = (result != kCFCompareEqualTo);
    CFBooleanRef throttleState =(CFBooleanRef) CFDictionaryGetValue(settingsDict, CFSTR("throttleOn"));
   // NSLog(@"Throttler state %@", throttleState);
    //CFStringRef bandwidth = CFSTR("500Kbit");
    Boolean throttleOn = CFBooleanGetValue(throttleState);
	char command[BUFSIZE], host[BUFSIZE];
	Boolean ok;
    
    
    

    //delete existing rules
	for(CFIndex i = 0; i < tunnelServerCount; i++) {
        int rule = 3000 + i;
        sprintf(command, "sudo -b /sbin/ipfw delete %ul", rule);
        if (!(in = popen(command, "r"))) {
            //exit(1);  
        }
        
        /* read the output of netstat, one line at a time */
        while (fgets(buff, sizeof(buff), in) != NULL ) {
            printf("ipfw result: %s", buff);
        }
    }
    

    
    
    
    // setup pipe
    if (throttleOn)
    {
        CFStringRef pipeCommand = CFStringCreateWithFormat(NULL, NULL, CFSTR("sudo -b /sbin/ipfw pipe 1 config bw %@Kbit"), throttleSpeed);
        CFStringGetCString(pipeCommand, command, sizeof(command), kCFStringEncodingUTF8);
        
        /* popen creates a pipe so we can read the output
         of the program we are invoking */
        if (!(in = popen(command, "r"))) {
            //exit(1);  
        }
        
        /* read the output of netstat, one line at a time */
        while (fgets(buff, sizeof(buff), in) != NULL ) {
            printf("ipfw result: %s", buff);
        }
        
        CFRelease(pipeCommand);
    }
    else
    {
        // delete pipe
        sprintf(command, "sudo -b /sbin/ipfw pipe 1 delete");
        //CFStringRef pipeCommand = CFStringCreateWithFormat(NULL, NULL, CFSTR("sudo -b /sbin/ipfw pipe 1 delete"), throttleSpeed);
        //CFStringGetCString(pipeCommand, command, sizeof(command), kCFStringEncodingUTF8);
        if (!(in = popen(command, "r"))) {
            //exit(1);  
        }
    }

    

    
    //add rule for each sever
	for(CFIndex i = 0; i < tunnelServerCount; i++) {
        int rule = 3000 + i;
        CFDictionaryRef server = CFArrayGetValueAtIndex(tunnelServers, i);

        ok = TRUE;
        ok &= CFStringGetCString(
                                     CFDictionaryGetValue(server, CFSTR("host")),
                                     host,
                                     BUFSIZE,
                                     kCFStringEncodingUTF8);
        if (!ok)
        {
            exit(-1);
        }
        
        if (throttleOn)
        {    
            sprintf(command, "sudo -b /sbin/ipfw add %i pipe 1 tcp from me to %s", rule, host);
            //fopen(command, "r");
            if (!(in = popen(command, "r"))) {
                exit(1);  
            }
            
            /* read the output of netstat, one line at a time */
            while (fgets(buff, sizeof(buff), in) != NULL ) {
                printf("ipfw result: %s", buff);
            }
        }
	}

    
    CFRelease(configDict);
    CFRelease(settingsDict);
   // CFRelease(settingsPath);
   // CFRelease(configPath);

    [pool drain];
	return WEXITSTATUS(ret);
}
