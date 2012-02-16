//
//  ADDExclusionsWindowController.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 6/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionsWindowController.h"

#import "ADDExclusionsVC.h"

@implementation ADDExclusionsWindowController

- (void)awakeFromNib
{
    self.viewController = [[[ADDExclusionsVC alloc] initWithNibName:nil bundle:nil] autorelease];
   // [self sizeToViewAnimate:NO];
    [super awakeFromNib]; // after setting viewController so windowWillShow message is received
}


@end
