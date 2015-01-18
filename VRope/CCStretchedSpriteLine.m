//
//  CCStretchedSpriteLine.m
//
//  Created by Peter Easdown on 24/04/12.
//

#import "CCStretchedSpriteLine.h"

@implementation CCStretchedSpriteLine {
    CCSprite *line;
    BOOL initialised;
    CGPoint fromPosition_;
    CGPoint toPosition_;
}

#define kLine 3

- (id) init {
    self = [super init];
    
    if (self != nil) {
    }
    
    return self;
}

- (id) initSpriteLineFrom:(CGPoint)fromPos to:(CGPoint)toPos andSpriteFrameName:(NSString*)spriteFrameName {

    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:spriteFrameName];
    
    self = [super initWithTexture:frame.texture rect:CGRectZero];

    if (self != nil) {
        initialised = NO;
        
        line = [CCSprite spriteWithSpriteFrameName:spriteFrameName];
        [self addChild:line z:0 tag:kLine];
        
        self.fromPosition = fromPos;
        self.toPosition = toPos;
        
        initialised = YES;
        
        [self updateLine];
    }
    
    return self;
}

- (void) cleanup {
    initialised = NO;
    
    [super cleanup];
}

+ (id) stretchedSpriteLineFrom:(CGPoint)fromPos to:(CGPoint)toPos andSpriteFrameName:(NSString*)spriteFrameName {
    CCStretchedSpriteLine *result = [[[CCStretchedSpriteLine alloc] initSpriteLineFrom:fromPos to:toPos andSpriteFrameName:spriteFrameName] autorelease];
    
    return result;
}

- (void) setOpacity:(GLubyte)opacity {
    [super setOpacity:opacity];
    [line setOpacity:opacity];
}

- (void) setFromPosition:(CGPoint)fromPosition {
    fromPosition_ = fromPosition;
    
    [self updateLine];
}

- (CGPoint) fromPosition {
    return fromPosition_;
}

- (void) setToPosition:(CGPoint)toPosition {
    toPosition_ = toPosition;
    
    [self updateLine];
}

- (CGPoint) toPosition {
    return toPosition_;
}

- (void) updateLine {
    if (initialised == NO) {
        return;
    }
    
    CGPoint p2 = fromPosition_;
    CGPoint p1 = toPosition_;
    
    float rads = ccpToAngle(ccpSub(p1, p2));
    float degs = CC_RADIANS_TO_DEGREES(rads); // convert to degrees
    degs += 90; // rotate
    degs *= -1; // clockwise
    
    [line setAnchorPoint:CGPointMake(0.5, 0.0)];
    [line setPosition:p1];
    lengthOfLine_ = ccpDistance(p1, p2);
    
    float scaleOfLine = lengthOfLine_ / [line contentSize].height;
    [line setScaleY:scaleOfLine];
    [line setRotation:degs];
}

- (float) length {
    return lengthOfLine_;
}

- (void) updateTransform {
    [self updateLine];
    [super updateTransform];
}

-(void) draw {
    [self updateLine];
    [super draw];
}

@end
