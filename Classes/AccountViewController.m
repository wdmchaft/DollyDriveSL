//
//  AccountViewController.m
//  DollyDriveApp
//
//  Created by Angelone John on 10/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AccountViewController.h"
#import "ADDAppConfig.h"
#import "ADDKeyManagement.h"

@implementation AccountViewController
@synthesize username, tabview;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (NSTabView*)tabView
{
    return self.tabview;
}

- (void) restoreTMConfigAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[NSApplication sharedApplication] terminate:nil];
}

- (IBAction)restoreTMPlist:(id)sender
{
    ADDAppConfig *appConfig = [ADDAppConfig sharedAppConfig];
    
    if (![appConfig timeMachinePlistBackupExists])
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"com.apple.TimeMachine.plist backup not found"];
        [alert setInformativeText:@"Sorry - we couldn't find the main configuration backup. Please check the Dolly Drive support web pages for information on resolving this."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
        return;
    }
    
    //TODO: move this stuff to AppConfig
    
    NSString *origBackupPath = [appConfig mainTimeMachinePlistBackupPath];
    NSString *dollyDriveConfigBackupPath = [appConfig dollyDriveTimeMachinePlistBackupPath];
    NSString *systemPlist = @"/Library/Preferences/com.apple.TimeMachine.plist";
    
    NSError *anError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:dollyDriveConfigBackupPath])
        [fm removeItemAtPath:dollyDriveConfigBackupPath error:&anError];
    
    if (!anError)
        [fm moveItemAtPath:systemPlist toPath:dollyDriveConfigBackupPath error:&anError];
    
    if (!anError)
        [fm copyItemAtPath:origBackupPath toPath:systemPlist error:&anError];
    
    if (anError)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"com.apple.TimeMachine.plist could not be replaced"];
        [alert setInformativeText:[NSString stringWithFormat:@"There was a problem replacing the configuration file. Please check the Dolly Drive support web pages for information on resolving this. (%@)", [anError localizedDescription]]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
        return;
        
    }
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Configuration successfully replaced"];
    [alert setInformativeText:@"Dolly Drive will now exit."];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                      modalDelegate:self
                     didEndSelector:@selector(restoreTMConfigAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
    
    
}

- (IBAction)accountDetails:(id)sender
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://10.0.4.9:30001/auth/users/login"]
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:60.0];
    [ [ NSWorkspace sharedWorkspace ] openURL:[request URL] ];
}

- (void) changeUserAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[NSApplication sharedApplication] terminate:nil];
}


- (IBAction)changeUser:(id)sender
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *anError = nil;
    
    [fm removeItemAtPath:[ADDServerConfig filePath] error:&anError];
    
    if (!anError)
    {
        ADDKeyManagement *km = [[[ADDKeyManagement alloc] init] autorelease];
        [fm removeItemAtPath:[km privateKeyFilePath] error:&anError];
        
        if (!anError)
            [fm removeItemAtPath:[km publicKeyFilePath] error:&anError];
    }
    
    if (anError)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Unable to remove all user settings"];
        [alert setInformativeText:@"You may wish to try removing the directory ~/Library/Application Settings/DollyDrive yourself or consult the Dolly Drive support web pages for more information."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
        
        return;
    }
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"User settings removed"];
    [alert setInformativeText:@"Dolly Drive will now exit. Next time you start Dolly Drive you will be able to login with any Dolly Drive User"];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[(NSWindowController *)self window]
                      modalDelegate:self
                     didEndSelector:@selector(restoreTMConfigAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
}



@end
