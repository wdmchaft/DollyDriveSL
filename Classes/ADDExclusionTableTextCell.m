//
//  ADDExclusionTableTextCell.m
//  DollyDriveApp
//
//  Created by Mark Aufflick on 11/01/11.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTableTextCell.h"


@implementation ADDExclusionTableTextCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [super drawWithFrame:NSInsetRect(cellFrame, 0, (cellFrame.size.height - 16) / 2) inView:controlView];
}


@end
