//
//  ADDExclusionsViewController.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 8/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionsVC.h"

#import "ADDExclusionTreeNodeBase.h"
#import "ADDExclusionTableCell.h"
#import "ADDExclusionTableTextCell.h"
#import "ADDAppConfig.h"
#import "ADDDiskSizeFormatter.h"
#import "ADDExclusionTreeNodeUsers.h"

@implementation ADDExclusionsVC

@synthesize model;
@synthesize excludeRootDirs;
@synthesize delegate;
@synthesize _exclusionsHelperTask;

- (void)awakeFromNib
{
    [self setTitle:@"Dolly Drive Assistant"];
    
    ADDExclusionTableCell *cell = [[[ADDExclusionTableCell alloc] init] autorelease];
    [cell setEditable:NO];
    [labelColumn setDataCell:cell];
 
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadDataOnMainThread)
                                                 name:(NSString *)ADDExclusionTreeNodeSizeOnDiskSetNotification
                                               object:nil];
    
}

- (void)reloadData
{
    [outlineView reloadData];
    [outlineView setNeedsDisplay];
}

- (void)reloadDataOnMainThread
{
    [self performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

#pragma mark -
#pragma mark NSOutlineViewDataSource methods

#define ADDExclusionsVCLabelColumnIdentifier @"LabelColumn"
#define ADDExclusionsVCSizeColumnIdentifier @"SizeColumn"

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    NSInteger numberOfChildren;
    
    if (item == nil)
    {
        numberOfChildren = [self.model.treeTopLevel count];
    }
    else 
    {
        NSArray *children = ((ADDExclusionTreeNodeBase *)item).children;
        numberOfChildren = children ? [children count] : 0;
    }
    
    return numberOfChildren;
}

- (BOOL)outlineView:(NSOutlineView *)theOutlineView isItemExpandable:(id)item
{
    return [self outlineView:theOutlineView numberOfChildrenOfItem:item] > 0 ? YES : NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)idx ofItem:(id)item
{
    ADDExclusionTreeNodeBase *childObject;
    
    if (item == nil)
    {
        childObject = [self.model.treeTopLevel objectAtIndex:idx];
    }
    else 
    {
        NSArray *children = ((ADDExclusionTreeNodeBase *)item).children;
        childObject = [children objectAtIndex:idx];
    }
    
    return childObject;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    id objectValue = nil;
    ADDExclusionTreeNodeBase *node = (ADDExclusionTreeNodeBase *)item;
    
    if ([[tableColumn identifier] isEqualToString:ADDExclusionsVCLabelColumnIdentifier])
    {
        objectValue = node.title;
    }
    else if ([[tableColumn identifier] isEqualToString:ADDExclusionsVCSizeColumnIdentifier])
    {
        if (node.sizeOnDisk)
        {
            ADDDiskSizeFormatter *formatter = [[[ADDDiskSizeFormatter alloc] init] autorelease];
            [formatter setMaximumFractionDigits:2];
            formatter.useBaseTenUnits = YES;
            
            // 1 is a sentinal for value is set but size is zero
            if (node.sizeOnDisk == 1)
            {
                objectValue = @"Empty";
            }
            else 
            {
                objectValue = [formatter stringFromNumber:[NSNumber numberWithUnsignedLongLong:node.sizeOnDisk]];
            }
        }
        else 
        {
            objectValue = @"Estimating size...";
        }
    }
    
    return objectValue;
}

#pragma mark -
#pragma mark NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView*)olv shouldExpandItem:(id)item
{
    return [(ADDExclusionTreeNodeBase *)item isExpandable];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES; // selection disabled in outlineview subclass
}

- (void)outlineView:(NSOutlineView*)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
    ADDExclusionTreeNodeBase *node = (ADDExclusionTreeNodeBase *)item;
    
    if ([[tableColumn identifier] isEqualToString:ADDExclusionsVCLabelColumnIdentifier])
    {
        // I don't really like how Apple's code changes the cell here - better to return an object
        // with all the data in the datasource?
                
    	NSImage *image = [NSClassFromString([node className]) smallIconForNode:node];
        if (!image)
            image = [NSImage imageNamed:NSImageNameMultipleDocuments];
        
        [(ADDExclusionTableCell*)cell setImage:image];
        [(ADDExclusionTableCell*)cell setNode:item]; // could instead use representedObject?
    }
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    return 35;
}

#pragma mark -
#pragma mark IBActions

- (IBAction)cancel:(id)sender
{
    [self.windowController close];
    [NSApp endSheet:self.view.window returnCode:NSCancelButton];
}

- (IBAction)save:(id)sender
{
    NSError *error = nil;
    if ([self.model saveBackupStateExcludingRootDirs:excludeRootDirs WithError:&error])
    {
        if (excludeRootDirs != [[[ADDAppConfig sharedAppConfig] serverConfig].excludeRootDirs boolValue])
        {
            [[ADDAppConfig sharedAppConfig] serverConfig].excludeRootDirs = [NSNumber numberWithBool:self.excludeRootDirs];
            [[[ADDAppConfig sharedAppConfig] serverConfig] saveToFile];
        }
        didSave = YES;
        [self.windowController close];
    }
    else 
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Error saving backup exclusions"];
        [alert setInformativeText:[error localizedDescription]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[(NSWindowController *)self.windowController window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:nil];
    }
    [NSApp endSheet:self.view.window returnCode:NSOKButton];
}

#pragma mark -
#pragma mark Notifications

- (NSTask *)startExclusionsHelperTask
{
    if (self._exclusionsHelperTask)
        return self._exclusionsHelperTask;
    
    self._exclusionsHelperTask = [[[NSTask alloc] init] autorelease];
    [self._exclusionsHelperTask setLaunchPath:[[ADDAppConfig sharedAppConfig] exclusionsHelperPath]];
    
    [self._exclusionsHelperTask launch];
    
    return self._exclusionsHelperTask;
}

- (void)showOutline
{
    [loadingString setHidden:NO];
    if (!self.model)
    {
        [self startExclusionsHelperTask];
    
        while (!self.model)
        {
            sleep(1);
            self.model = (ADDExclusionsModel *)[[NSConnection
                                                 rootProxyForConnectionWithRegisteredName:@"svr"
                                                 host:nil] retain];
        }
    }

    [outlineView reloadData];
    
    self.excludeRootDirs = [[[ADDAppConfig sharedAppConfig] serverConfig].excludeRootDirs boolValue];
    
    //TODO: if this is the first time round, we should show suggestions incl. unchecking all Volumes, vmware etc.
    
    // expand users
    
    for (ADDExclusionTreeNodeBase *node in self.model.treeTopLevel)
        if ([node isKindOfClass:[ADDExclusionTreeNodeUsers class]])
            [outlineView expandItem:node];
    
    [loadingString setHidden:YES];
    didSave = NO;
}

- (void)windowWillClose:(NSNotification *)notification
{
    self.model = nil;
    [self releaseExclusionsHelper];
    [loadingString setHidden:NO];
    if (didSave)
        [delegate exclusionsDidSave];
    else 
        [delegate exclusionsDidCancel];
        
}

#pragma mark -
#pragma mark cleanup

- (void)releaseExclusionsHelper
{
    if ([_exclusionsHelperTask isRunning])
    {
        [self.model exit];
    }
    
    ReleaseAndNil(_exclusionsHelperTask);
}

- (void)dealloc
{
    self.delegate = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:(NSString *)ADDExclusionTreeNodeSizeOnDiskSetNotification
                                                  object:nil];
    
    [self releaseExclusionsHelper];
    
    ReleaseAndNil(model);
    
    [super dealloc];
}

@end
