//
//  ADDFeedbackWindowController.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 13/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDFeedbackWindowController.h"

#import "ADDFeedbackVC.h"

@implementation ADDFeedbackWindowController

- (void)awakeFromNib
{
    self.viewController = [[[ADDFeedbackVC alloc] initWithNibName:nil bundle:nil] autorelease];
    [self sizeToViewAnimate:NO];
    [super awakeFromNib]; // after setting viewController so windowWillShow message is received
}

@end
