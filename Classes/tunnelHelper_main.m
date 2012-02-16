#include <CoreFoundation/CoreFoundation.h>
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
        NSLog(@"Could not read config file data due to error code %d", (int)errorCode);
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

// a random-enough full cycle LCG for any likely number of tunnel endpoints
UInt16 nextCandidate(UInt16 thisCandidate, UInt16 candidateCount) {
	static int stride = 0;
	static UInt32 strides[] = {65537, 65539, 65543, 65551, 65557, 65563, 65579, 65581, 65587, 65599, 65609, 65617, 65629, 65633, 65647, 65651};
	if (stride == 0) {
		stride = strides[random() & 0xf];
	}
	return ((UInt32)thisCandidate + stride) % candidateCount;
}

int main (int argc, const char * argv[]) {
    
	CFDictionaryRef configDict;
	char **sshargv;
	int ret = 2;

	if(argc != 2) {
		fprintf(stderr, "usage: %s .../config.plist\n", argv[0]);
		exit(1);
	}

	srandomdev();

	configDict = configCreateFromFile(argv[1]);
	CFArrayRef tunnelServers = CFDictionaryGetValue(configDict, CFSTR("tunnelServers"));
	UInt16 tunnelServerCount = CFArrayGetCount(tunnelServers);
	UInt16 tunnelServerCurrent = random() % tunnelServerCount; // first item in the list
	CFStringRef tunnelIdentity = CFDictionaryGetValue(configDict, CFSTR("tunnelIdentity"));
	CFArrayRef tunnelArgs = CFDictionaryGetValue(configDict, CFSTR("tunnelArgs"));
	char identity[BUFSIZE], host[BUFSIZE], portString[BUFSIZE], user[BUFSIZE];
	Boolean ok;
	// sshargv is ssh (tunnelArgs) -i (tunnelIdentity) -l (tunnerServers.user) -p (tunnerServers.portString) (tunnerServers.host)
	sshargv = (char**)calloc(CFArrayGetCount(tunnelArgs) + 8, sizeof(char *));
	sshargv[0] = "/usr/bin/ssh";
	for(int i = 0; i < CFArrayGetCount(tunnelArgs); i++) {
		CFStringRef cfarg = CFArrayGetValueAtIndex(tunnelArgs, i);
		CFIndex cfargchars = CFStringGetLength(cfarg);
		char *arg = malloc(cfargchars + 1); //TODO: how does this deal with possible wide chars? probably not well...
		ok = CFStringGetCString(cfarg, arg, cfargchars + 1, kCFStringEncodingUTF8);
        if (!ok)
        {
            exit(-1);
        }
        
		sshargv[i+1] = arg;
	}
	ok = CFStringGetCString(tunnelIdentity, identity, BUFSIZE, kCFStringEncodingUTF8);
    if (!ok)
    {
        exit(-1);
    }
	//TODO: die if !ok
	sshargv[CFArrayGetCount(tunnelArgs) + 1] = "-i";
	sshargv[CFArrayGetCount(tunnelArgs) + 2] = identity;
	sshargv[CFArrayGetCount(tunnelArgs) + 3] = "-l";
	sshargv[CFArrayGetCount(tunnelArgs) + 4] = user;
	sshargv[CFArrayGetCount(tunnelArgs) + 5] = "-p";
	sshargv[CFArrayGetCount(tunnelArgs) + 6] = portString;
	sshargv[CFArrayGetCount(tunnelArgs) + 7] = host;

	for(CFIndex i = 0; i < tunnelServerCount; i++) {
		tunnelServerCurrent = nextCandidate(tunnelServerCurrent, tunnelServerCount);
		if (fork() == 0) {
			int port;
			CFDictionaryRef server = CFArrayGetValueAtIndex(tunnelServers, tunnelServerCurrent);
			ok = TRUE;
			ok &= CFStringGetCString(
				CFDictionaryGetValue(server, CFSTR("host")),
				host,
				BUFSIZE,
				kCFStringEncodingUTF8);
			ok &= CFNumberGetValue(
				CFDictionaryGetValue(server, CFSTR("port")),
				kCFNumberIntType,
				&port);
			sprintf(portString, "%d", port);
			ok &= CFStringGetCString(
				CFDictionaryGetValue(server, CFSTR("user")),
				user,
				BUFSIZE,
				kCFStringEncodingUTF8);
            if (!ok)
            {
                exit(-1);
            }
			execvp("ssh", sshargv);
			fprintf(stderr, "couldn't exec!");
			exit(1);
		}
		wait(&ret);
		if(WIFEXITED(ret) && WEXITSTATUS(ret) == 0) {
			break;
		}
	}
    
    CFRelease(configDict);
    
	return WEXITSTATUS(ret);
}
