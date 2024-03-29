/*
 *     Generated by class-dump 3.3.2 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2010 by Steve Nygard.
 */

#import "NSSlider.h"

@interface TMSlider : NSSlider
{
    double _targetValue;
}

+ (id)defaultAnimationForKey:(id)arg1;
+ (id)keyPathsForValuesAffectingAnimating;
- (BOOL)animating;
- (BOOL)isFlipped;
- (void)moveDown:(id)arg1;
- (void)moveLeft:(id)arg1;
- (void)moveRight:(id)arg1;
- (void)moveUp:(id)arg1;
- (void)pageDown:(id)arg1;
- (void)pageUp:(id)arg1;
- (void)setDoubleValue:(double)arg1 animate:(BOOL)arg2;
- (void)setTargetValue:(double)arg1;
- (double)targetValue;

@end

