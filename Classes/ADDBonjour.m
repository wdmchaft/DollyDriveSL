//
//  ADDBonjour.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 14/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

//NB: most of this was taken verbatim from the old Pref Pane with a few corrections - it needs rewriting

#import "ADDBonjour.h"

#import "ADDAppConfig.h"
#import "ADDServerConfig.h"

#include "dns_sd.h"
#include <netdb.h>			// For getaddrinfo()
#include <arpa/inet.h>


// these seem to be slurped from mDNSShared/dnssd_clientstub.c
//static uint32_t opinterface = kDNSServiceInterfaceIndexAny;
typedef union { unsigned char b[2]; unsigned short NotAnInteger; } Opaque16;
static DNSRecordRef record = NULL;

#define HexVal(X) ( ((X) >= '0' && (X) <= '9') ? ((X) - '0'     ) :  \
((X) >= 'A' && (X) <= 'F') ? ((X) - 'A' + 10) :  \
((X) >= 'a' && (X) <= 'f') ? ((X) - 'a' + 10) : 0)

#define HexPair(P) ((HexVal((P)[0]) << 4) | HexVal((P)[1]))

static void ShowTXTRecord(uint16_t txtLen, const unsigned char *txtRecord)
{
	const unsigned char *ptr = txtRecord;
	const unsigned char *max = txtRecord + txtLen;
	while (ptr < max)
	{
		const unsigned char *const end = ptr + 1 + ptr[0];
		if (end > max) { printf("<< invalid data >>"); break; }
		if (++ptr < end) printf(" ");   // As long as string is non-empty, begin with a space
		while (ptr<end)
		{
			// We'd like the output to be shell-friendly, so that it can be copied and pasted unchanged into a "dns-sd -R" command.
			// However, this is trickier than it seems. Enclosing a string in double quotes doesn't necessarily make it
			// shell-safe, because shells still expand variables like $foo even when they appear inside quoted strings.
			// Enclosing a string in single quotes is better, but when using single quotes even backslash escapes are ignored,
			// meaning there's simply no way to represent a single quote (or apostrophe) inside a single-quoted string.
			// The only remaining solution is not to surround the string with quotes at all, but instead to use backslash
			// escapes to encode spaces and all other known shell metacharacters.
			// (If we've missed any known shell metacharacters, please let us know.)
			// In addition, non-printing ascii codes (0-31) are displayed as \xHH, using a two-digit hex value.
			// Because '\' is itself a shell metacharacter (the shell escape character), it has to be escaped as "\\" to survive
			// the round-trip to the shell and back. This means that a single '\' is represented here as EIGHT backslashes:
			// The C compiler eats half of them, resulting in four appearing in the output.
			// The shell parses those four as a pair of "\\" sequences, passing two backslashes to the "dns-sd -R" command.
			// The "dns-sd -R" command interprets this single "\\" pair as an escaped literal backslash. Sigh.
			if (strchr(" &;`'\"|*?~<>^()[]{}$", *ptr)) printf("\\");
			if      (*ptr == '\\') printf("\\\\\\\\");
			else if (*ptr >= ' ' ) printf("%c",        *ptr);
			else                   printf("\\\\x%02X", *ptr);
			ptr++;
		}
	}
}

void reg_reply
(
 DNSServiceRef                       sdRef,
 DNSServiceFlags                     flags,
 DNSServiceErrorType                 errorCode,
 const char                          *name,
 const char                          *regtype,
 const char                          *domain,
 void                                *context
 )
{
    // registration reply
    printf("Got a reply from the server with error %d\n", errorCode);
    return;
}

static DNSServiceErrorType RegisterService(DNSServiceRef *sdRef,
										   const char *nam, const char *typ, const char *dom, const char *host, uint16_t port, int argc, char *argv[])
{
	unsigned char txt[2048] = "";
	unsigned char *ptr = txt;
	int i;
	
	if (nam[0] == '.' && nam[1] == 0) nam = "";   // We allow '.' on the command line as a synonym for empty string
	if (dom[0] == '.' && dom[1] == 0) dom = "";   // We allow '.' on the command line as a synonym for empty string
	
	printf("Registering Service %s.%s%s%s", nam[0] ? nam : "<<Default>>", typ, dom[0] ? "." : "", dom);
	if (host && *host) printf(" host %s", host);
	printf(" port %d\n", port);
	
	if (argc)
	{
		for (i = 0; i < argc; i++)
		{
			const char *p = argv[i];
			*ptr = 0;
			while (*p && *ptr < 255 && ptr + 1 + *ptr < txt+sizeof(txt))
			{
				if      (p[0] != '\\' || p[1] == 0)                       { ptr[++*ptr] = *p;           p+=1; }
				else if (p[1] == 'x' && isxdigit(p[2]) && isxdigit(p[3])) { ptr[++*ptr] = HexPair(p+2); p+=4; }
				else                                                      { ptr[++*ptr] = p[1];         p+=2; }
			}
			ptr += 1 + *ptr;
		}
		ShowTXTRecord(ptr-txt, txt);
		printf("\n");
	}
    
    ADDServerConfig *serverConfig = [ADDAppConfig sharedAppConfig].serverConfig;
	
	DNSServiceErrorType ret = DNSServiceRegister(
                                                 sdRef,
                                                 kDNSServiceFlagsNoAutoRename, // don't auto-rename - TODO: handle callback
                                                 kDNSServiceInterfaceIndexLocalOnly,
                                                 [serverConfig.afpVolumeName cStringUsingEncoding:NSASCIIStringEncoding], //nam,
                                                 typ,
                                                 NULL, //dom,
                                                 host,
                                                 htons(port),
                                                 (uint16_t) (ptr-txt),
                                                 txt,
                                                 reg_reply,
                                                 NULL
                                                 );
    
    NSLog(@"DNSServiceRegister ret: %d", ret);
    
    return ret;
}

static unsigned long get_ip(const char *const name)
{
	unsigned long ip = 0;
	struct addrinfo hints;
	struct addrinfo * addrs = NULL;
	
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	
	if (getaddrinfo(name, NULL, &hints, &addrs) == 0)
	{
		ip = ((struct sockaddr_in*) addrs->ai_addr)->sin_addr.s_addr;
	}
	
	if (addrs)
	{
		freeaddrinfo(addrs);
	}
	
	return(ip);
}

void bonjourRegisterRecordReplyCallback ( 
                                        DNSServiceRef sdRef, 
                                        DNSRecordRef RecordRef, 
                                        DNSServiceFlags flags, 
                                        DNSServiceErrorType errorCode, 
                                        void *context )
{
    NSLog(@"Recieved record reply callback with error: %d for host: %s", errorCode, (char *)context);
}

static DNSServiceErrorType RegisterProxyAddressRecord(DNSServiceRef *sdRef, const char *host, const char *ip)
{
	// Call getip() after the call DNSServiceCreateConnection().
	// On the Win32 platform, WinSock must be initialized for getip() to succeed.
	// Any DNSService* call will initialize WinSock for us, so we make sure
	// DNSServiceCreateConnection() is called before getip() is.
	unsigned long addr = 0;
	DNSServiceErrorType err = DNSServiceCreateConnection(sdRef);
	if (err) { fprintf(stderr, "DNSServiceCreateConnection returned %d\n", err); return(err); }
	addr = get_ip(ip);
    
    ADDServerConfig *serverConfig = [ADDAppConfig sharedAppConfig].serverConfig;
    
    // has to be unique on lan, even if you are only advertising for localhost - just using share name
    //NSString *fullName = [NSString stringWithFormat:@"%s_%@", host, serverConfig.afpVolumeName];
    
	DNSServiceErrorType ret = DNSServiceRegisterRecord(
                                                       *sdRef,
                                                       &record,
                                                       kDNSServiceFlagsUnique,
                                                       kDNSServiceInterfaceIndexLocalOnly,
                                                       [serverConfig.afpVolumeName cStringUsingEncoding:NSASCIIStringEncoding],
                                                       kDNSServiceType_A,
                                                       kDNSServiceClass_IN,
                                                       sizeof(addr),
                                                       &addr,
                                                       240,
                                                       NULL,
                                                       (void*)host
                                                       );
	// Note, should probably add support for creating proxy AAAA records too, one day
    
    NSLog(@"DNSServiceRegisterRecord ret: %d", ret);
    
    return ret;
    
}

@implementation ADDBonjour

@synthesize error;

- (BOOL)regService
{		
	DNSServiceRef dns_client;
	DNSServiceErrorType err;
    
    ADDServerConfig *serverConfig = [ADDAppConfig sharedAppConfig].serverConfig;

	const char *domainChar = [[NSString stringWithFormat:@"%@:%d", ADDAFPForwardingHost, ADDAFPForwardingPort] cStringUsingEncoding:NSASCIIStringEncoding];
	const char *ipChar = [ADDAFPForwardingHostIP cStringUsingEncoding:NSASCIIStringEncoding];
	uint16_t port = [serverConfig.bonjourPort intValue]; // don't quite know what this is - need to learn more about Bonjour;
	
	err = RegisterProxyAddressRecord(&dns_client, domainChar, ipChar);
	if (err)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"RegisterProxyAddressRecord failed"
                                         code:err
                                     userInfo:nil];
        return NO;
    }

	// RegisterService(ref, name, type, domain, port
	// "dk1=adVN=demo01,adVF=0x81,adVU=32E5B653-573E-45B6-AB68-2A4036963949"
	// 32E5B653-573E-45B6-AB68-2A4036963949
	NSString *text = [[NSString alloc] initWithFormat:@"dk1=adVN=%@,adVF=0x81,adVU=%@", serverConfig.afpVolumeName, serverConfig.volumeUUID];
	const char *txt = [text cStringUsingEncoding:NSASCIIStringEncoding];
	[text release];
	char *argv[1];
	argv[0] = (char *)txt;
	
	err = RegisterService(&dns_client, "DollyDrive", "_adisk._tcp", "local", domainChar, port, 1, argv);

	if (err)
    {
        //TODO: proper error domain
        self.error = [NSError errorWithDomain:@"RegisterService failed"
                                         code:err
                                     userInfo:nil];
        return NO;
    }

	return YES;
}

@end
