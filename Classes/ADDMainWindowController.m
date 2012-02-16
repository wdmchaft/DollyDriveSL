//
//  ADDWindowController.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 7/12/10.
//  Copyright 2010 Pumptheory. All rights reserved.
//

#import "ADDMainWindowController.h"

#import "ADDAskUserDetailsVC.h"
#import "ADDInfoView.h"
#import "ADDAppConfig.h"
#import "ActionViewController.h"

@implementation ADDMainWindowController

- (void)awakeFromNib
{
    [self changeViewController:ADDViewControllerAskUserDetails]; //ADDViewControllerAskUserDetails];  ADDViewControllerActions
    [super awakeFromNib]; // after setting viewController so windowWillShow message is received
    
    if ([[ADDAppConfig sharedAppConfig] apiPortIsStaging])
    {
        [mainLogo setImage:[NSImage imageNamed:@"DollyLabs"]];
    }
}

- (void)changeViewController:(ADDViewController)vcId
{
    CGFloat priorHeight = -1;
    //CGFloat priorTop = 0;
    if (self.viewController)
    {
        priorHeight = [self.viewController.view frame].size.height;
        //priorTop = self.viewController.view.frame.origin.y;
    }
    
    MGAViewController *theVC = nil;
    
    switch (vcId)
    {
        case ADDViewControllerAskUserDetails:
            theVC = [[ADDAskUserDetailsVC alloc] initWithNibName:nil bundle:nil];
            break;
            
        case ADDViewControllerInfoView:
            theVC  = [[ActionViewController alloc] initWithNibName:nil bundle:nil];  //ADDInfoView
            break;
            
        case ADDViewControllerActions:
            theVC  = [[ActionViewController alloc] initWithNibName:nil bundle:nil];
            break;
    }
        
    // all frames are the same width
    [self resizeToViewHeight:[theVC.view frame].size.height fromHeight:priorHeight animate:NO];
    
    self.viewController = [theVC autorelease];
}

@end
