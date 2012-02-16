//
//  ADDExclusionTableCell.h
//
//  Based on Apple sample code "ImageAndTextCell.h" Copyright � 2006, Apple. All rights reserved.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADDExclusionTreeNodeBase.h"

@interface ADDExclusionTableCell : NSTextFieldCell
{
@private
    NSImage	*image;
    ADDExclusionTreeNodeBase *node; // can also get the image from here
    NSButtonCell *checkboxCell;
}

- (void)setNode:(ADDExclusionTreeNodeBase *)node;
- (void)setImage:(NSImage *)anImage;
- (NSImage *)image;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

- (void)divideFrame:(NSRect)cellFrame 
     intoImageFrame:(NSRect *)imageFrame 
imageBackgroundFrame:(NSRect *)imgBgFrame
      checkboxFrame:(NSRect *)cbFrame 
          textFrame:(NSRect *)textFrame
          isFlipped:(BOOL)isFlipped;

@end
