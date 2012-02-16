//
//  ADDCloneWindowController.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 4/04/11.
//  Copyright 2011 Pumptheory Pty Ltd. All rights reserved.
//

#import "ADDCloneWindowController.h"
#import "CVMainController.h"
#import "ADDColouredView.h"

@implementation ADDCloneWindowController

@synthesize delegate=_delegate;
@synthesize cloneController=_cloneController;
@synthesize colouredView=_colouredView;
@synthesize cloneControllerView=_cloneControllerView;

+ (NSSet *)keyPathsForValuesAffectingCloneInstructions
{
    return [NSSet setWithObjects:@"cloneController.incremental", @"cloneController.window", nil];
}

- (void)awakeFromNib
{
    self.colouredView.backgroundColour = [NSColor colorWithCalibratedRed:0.616 green:0.698 blue:0.678 alpha:1.];
    self.cloneController.delegate = self;
    self.cloneController.progressWindowSize = NSMakeSize (420, 164);
}

- (id)init
{
    self = [self initWithWindowNibName:@"ADDCloneWindow"];
    return self;
}

- (void)windowWillClose:(NSNotification *)notif
{
    if (self.delegate)
        [self.delegate cloneWindowWillClose];
}

- (void)alertDidEnd:(NSAlert *)alert
         returnCode:(NSInteger)returnCode
{
    if (returnCode != NSAlertFirstButtonReturn)
        return;
    
    [self.cloneController abort:self];
    
    [self.window close];
}

- (BOOL)windowShouldClose:(NSNotification*)note
{
    if (self.cloneController.busy)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:
         NSLocalizedString (@"CloneInProgressTitle",
                            @"Message Text")];
        [alert setInformativeText:
         NSLocalizedString (@"CloneInProgressMessage", @"Informative Text")];

        [alert addButtonWithTitle:NSLocalizedString (@"Stop Clone", @"Button Title")];
        [alert addButtonWithTitle:NSLocalizedString (@"Continue", @"Button Title")];
        
        [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@""];
        [[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\x1b"];
        
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:@selector (alertDidEnd:returnCode:)
                            contextInfo:NULL];
        
        return NO;
    }
    
    return YES;
}

- (void)windowDidLoad
{
    NSLog(@"Cloning Window DidLoad");
}

- (NSAttributedString*)cloneInstructions
{
    NSMutableParagraphStyle* style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    
    [style setAlignment:NSCenterTextAlignment];
    
    NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSColor whiteColor], NSForegroundColorAttributeName,
                                    style, NSParagraphStyleAttributeName, nil];
    
    NSString* instructions = self.cloneController.incremental ? NSLocalizedString(@"IncrementalInstructions", nil) : NSLocalizedString(@"NewCloneInstructions", nil);
    
    
    NSAttributedString* string = [[NSAttributedString alloc] initWithString:instructions
                                                                 attributes:attributes];
    
    [style release];
    
    return [string autorelease];
}

- (void)showIncremental
{
    self.cloneController.incremental = YES;
    [self showWindow:self];
}

- (void)showNewClone
{
    self.cloneController.incremental = NO;
    [self showWindow:self];
}

- (void)dealloc
{
    [_cloneController setDelegate:nil];
    [_cloneController release], _cloneController = nil;
    [_colouredView release], _colouredView = nil;
    
    [super dealloc];
}

#pragma mark -
#pragma mark CVMainControllerDelegate methods

- (void)windowWillResizeToProgressRect:(NSRect)rect
{
    _origControllerFrame = [self.cloneControllerView frame];
    _origWindowSize = [[self window] frame].size;
    NSRect f = _origControllerFrame;
    f.origin = NSMakePoint(0, 0);
    f.size = [[[self window] contentView] frame].size;
    [self.cloneControllerView setFrame:f];
    
    [self.colouredView removeFromSuperview];
}

- (void)windowWillResizeToMainRect:(NSRect)rect
{
    NSRect f = [[[self window] contentView] frame];
    f.size.height -= [self.colouredView frame].size.height -17; //hack
    [self.cloneControllerView setFrame:f];
}

- (void)windowDidResizeToMainRect:(NSRect)rect
{
    [[[self window] contentView] addSubview:self.colouredView];
}

@end
