//
//  ADDExclusionTableCell.m
//
//  Based on Apple sample code "ImageAndTextCell.m" Copyright � 2006, Apple. All rights reserved.
//  Copyright 2011 Pumptheory. All rights reserved.
//

#import "ADDExclusionTableCell.h"

@implementation ADDExclusionTableCell

- (id)init
{
    if ((self = [super init]))
    {
        checkboxCell = [[NSButtonCell alloc] init];
        [checkboxCell setButtonType:NSSwitchButton];
        [checkboxCell setTitle:@""];
        [checkboxCell setAllowsMixedState:YES];
    }
    
    return self;
}

- (void)dealloc {
    ReleaseAndNil(image);
    ReleaseAndNil(checkboxCell);
    ReleaseAndNil(node);
    
    [super dealloc];
}

- copyWithZone:(NSZone *)zone
{
    // No thanks to funky NSCell object/memory copying...
    ADDExclusionTableCell *cell = (ADDExclusionTableCell *)[super copyWithZone:zone];
    
    cell->image = [image retain];
    cell->node = [node retain];
    cell->checkboxCell = [checkboxCell copyWithZone:zone]; // can this just be retain?
    
    return cell;
}

- (void)setImage:(NSImage *)anImage
{
    if (anImage != image)
	{
        [image release];
        image = [anImage retain];
    }
}

- (void)setNode:(ADDExclusionTreeNodeBase *)aNode
{
    if (aNode != node)
    {
        [node release];
        node = [aNode retain];
    }
}

- (NSImage *)image
{
    return image;
}

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame
{
    if (image != nil)
	{
        NSRect imageFrame;
        imageFrame.size = [image size];
        imageFrame.origin = cellFrame.origin;
        imageFrame.origin.x += 3;
        imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
        return imageFrame;
    }
    else
        return NSZeroRect;
}

/*
 * never allowing editing
 
- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
    [super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}
 */

/*
 * never allowing selection
 
- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength;
{
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
    
    
    [super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
    
    // the frame will be wrong
    //[checkboxCell selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
    //[checkboxCell drawWithFrame:textFrame inView:controlView];    
}
 */

- (void)divideFrame:(NSRect)cellFrame 
     intoImageFrame:(NSRect *)imageFrame 
imageBackgroundFrame:(NSRect *)imgBgFrame
      checkboxFrame:(NSRect *)cbFrame 
          textFrame:(NSRect *)textFrame
          isFlipped:(BOOL)isFlipped
{
    if (image != nil)
	{
        NSSize imageSize = [image size];
        
        NSDivideRect(cellFrame, imageFrame, &cellFrame, 6 + imageSize.width, NSMinXEdge);
        
        *imgBgFrame = *imageFrame;
        
        imageFrame->origin.x += 3;
        imageFrame->size = imageSize;
        
        if (isFlipped)
            imageFrame->origin.y += ceil((cellFrame.size.height + imageFrame->size.height) / 2);
        else
            imageFrame->origin.y += ceil((cellFrame.size.height - imageFrame->size.height) / 2);
    }
    
    NSDivideRect(cellFrame, cbFrame, &cellFrame, [checkboxCell cellSize].width, NSMinXEdge);
    
    *cbFrame = NSInsetRect(*cbFrame, 0, 1);

    *textFrame = NSInsetRect(cellFrame, 0, (cellFrame.size.height - 16) / 2);
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
    //TODO: correctly handle mouse down -> move away -> mouse up
    NSRect imageFrame, imgBgFrame, checkboxFrame, textFrame;
    
    [self divideFrame:cellFrame 
       intoImageFrame:&imageFrame 
 imageBackgroundFrame:&imgBgFrame
        checkboxFrame:&checkboxFrame
            textFrame:&textFrame
            isFlipped:[controlView isFlipped]];
    
    NSPoint point = [controlView convertPoint:[event locationInWindow] fromView:nil];

    if (NSMouseInRect(point, checkboxFrame, [controlView isFlipped]))
    {
        [checkboxCell setState:!node.selected];
        node.selected = !node.selected;
        
        [(NSOutlineView *)controlView reloadData]; // to reflect any mixed state button changes
        return NSCellHitTrackableArea | NSCellHitContentArea;
    }

    return [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSRect imageFrame, imgBgFrame, checkboxFrame, textFrame;
    
    [self divideFrame:cellFrame 
       intoImageFrame:&imageFrame 
 imageBackgroundFrame:&imgBgFrame
        checkboxFrame:&checkboxFrame
            textFrame:&textFrame
            isFlipped:[controlView isFlipped]];
    
    if (image != nil)
	{
        if ([self drawsBackground])
		{
            [[self backgroundColor] set];
            NSRectFill(imgBgFrame);
        }
        
        [image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
    }
    
    [super drawWithFrame:textFrame inView:controlView];
    
    [checkboxCell setState:[node checkboxState]];
    [checkboxCell drawWithFrame:checkboxFrame inView:controlView];
}

- (NSSize)cellSize
{
    NSSize cellSize = [super cellSize];
    cellSize.width += (image ? [image size].width : 0) + 3;
    cellSize.width += [checkboxCell cellSize].width;
    return cellSize;
}

@end

