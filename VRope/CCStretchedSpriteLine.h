//
//  CCStretchedSpriteLine.h
//
//  Created by Peter Easdown on 24/04/12.
//

#import <Foundation/Foundation.h>

@interface CCStretchedSpriteLine : CCSprite {
    
    int firstSpriteTag;
    float lengthOfLine_;
}

// Create a 'line' between two points by stretching the specified sprite between those two points.
//
+ (id) stretchedSpriteLineFrom:(CGPoint)fromPos to:(CGPoint)toPos andSpriteFrameName:(NSString*)spriteFrameName;

// Returns the length of the line.
//
@property (assign, readonly) float length;

// The starting point of the line.
//
@property (assign) CGPoint fromPosition;

// The ending point of the line.
//
@property (assign) CGPoint toPosition;

@end
