//
//  ADDPrefsWindowController.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 23/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDPrefsWindowController.h"

#import "ADDPrefsVC.h"


@implementation ADDPrefsWindowController

- (void)awakeFromNib
{
    self.viewController = [[[ADDPrefsVC alloc] initWithNibName:nil bundle:nil] autorelease];
    [self sizeToViewAnimate:NO];
    [super awakeFromNib]; // after setting viewController so windowWillShow message is received
}

@end
