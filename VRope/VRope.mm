/*
 
 MIT License.
 
 Copyright (c) 2012 Flightless Ltd.  
 Copyright (c) 2010 Clever Hamster Games.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
*/

//
//  VRope.m
//
//  Created by patrick on 16/10/2010.
//

#import "VRope.h"

// Set this to 1 if you want each sprite that forms the rope to be stretched so that they always join.  Without this,
// sometimes your rope can become 'gappy' if it is stretched by movement, etc.
//
#define USE_STRETCHED_SPRITE 0

#if USE_STRETCHED_SPRITE == 1
#import "CCStretchedSpriteLine.h"
#endif

@implementation VRope

#if PHYSICS_INTEGRATION_ENABLED == 1

#if CC_ENABLE_BOX2D_INTEGRATION == 1

#define vrGetPosition(body) body->GetPosition()
#define vrGetAnchorA(joint) joint->GetAnchorA()
#define vrGetAnchorB(joint) joint->GetAnchorB()
#define vrGetDistance(joint) ccpDistance(vrGetAnchorA(joint), vrGetAnchorB(joint))

#elif CC_ENABLE_CHIPMUNK_INTEGRATION == 1

#define vrGetPosition(body) cpBodyGetPos(body)
#define vrGetAnchorA(joint) ccpAdd(cpSlideJointGetAnchr1(joint), cpBodyGetPos(cpConstraintGetA(joint)))
#define vrGetAnchorB(joint) ccpAdd(cpSlideJointGetAnchr2(joint), cpBodyGetPos(cpConstraintGetB(joint)))
#define vrGetDistance(joint) cpSlideJointGetMax(joint)

#endif

-(id)init:(vrBody*)body1 body2:(vrBody*)body2 batchNode:(CCSpriteBatchNode*)ropeBatchNode {
    return [self init:body1 body2:body2 batchNode:ropeBatchNode spriteFrameName:@"longrope.png"];
}

-(id)init:(vrBody*)body1 body2:(vrBody*)body2 batchNode:(CCSpriteBatchNode*)ropeBatchNode spriteFrameName:(NSString*)frameName {
	if((self = [super init])) {
		bodyA = body1;
		bodyB = body2;
		spriteSheet = ropeBatchNode;
        self.ropeFrameName = frameName;
        [self createRopeWithParameters:[self getCurrentParameters]];
	}
	return self;
}

// Flightless, init rope using a joint between two bodies
-(id)init:(vrJoint*)joint batchNode:(CCSpriteBatchNode*)ropeBatchNode {
    if((self = [super init])) {
		jointAB = joint;
		spriteSheet = ropeBatchNode;
        self.ropeFrameName = @"longrope.png";
		[self createRopeWithParameters:[self getCurrentParameters]];
	}
	return self;
}

- (RopeParameters) getCurrentParameters {
    RopeParameters result;
    
    if (bodyA) {
        result.pointA = ccp(vrGetPosition(bodyA).x*PTM_RATIO,vrGetPosition(bodyA).y*PTM_RATIO);
        result.pointB = ccp(vrGetPosition(bodyB).x*PTM_RATIO,vrGetPosition(bodyB).y*PTM_RATIO);
        result.length = ccpDistance(result.pointA, result.pointB);
    } else {
        result.pointA = ccp(vrGetAnchorA(jointAB).x*PTM_RATIO,vrGetAnchorA(jointAB).y*PTM_RATIO);
        result.pointB = ccp(vrGetAnchorB(jointAB).x*PTM_RATIO,vrGetAnchorB(jointAB).y*PTM_RATIO);
        
        // Don't use ccpDistance for this because some variations of vrJoint (e.g. chipmunk) actually
        // support a maximum length which is more useful than the current length.
        //
        result.length = vrGetDistance(jointAB);
    }

    return result;
}

-(void)reset {
    [self resetWithParameters:[self getCurrentParameters]];
}

-(void)update:(float)dt {
    [self updateWithParameters:[self getCurrentParameters] dt:dt];
}

// Flightless, update rope by pre-integrating the gravity each step (optimised for changing gravity)
-(void)updateWithPreIntegratedGravity:(float)dt gravityX:(float)gravityX gravityY:(float)gravityY {
    // update points with pre-integrated gravity
	[self updateWithParameters:[self getCurrentParameters] gxdt:gravityX*dt gydt:gravityY*dt];
}

// Flightless, update rope by pre-integrating the gravity each step (optimised for changing gravity)
// nb. uses current global point gravity, should probably be moved to a gravity for each rope
-(void)updateWithPreIntegratedGravity:(float)dt {
    // pre-integrate current gravity
    CGPoint gravity = ccpMult([VPoint getGravity], dt);
        
    // update points with pre-integrated gravity
	[self updateWithParameters:[self getCurrentParameters] gxdt:gravity.x gydt:gravity.y];
}

// Flightless, update rope by pre-integrating the gravity each step (optimised for changing gravity)
// nb. this uses a gravity with origin (0,0) and an average of bodyA and bodyB positions to determine which way is 'down' for each rope.
-(void)updateWithPreIntegratedOriginGravity:(float)dt {
    RopeParameters parameters = [self getCurrentParameters];
    
    // pre-integrate gravity, based on average position of bodies
    CGPoint gravityAtPoint = ccp(-0.5f*(parameters.pointA.x+parameters.pointB.x), -0.5f*(parameters.pointA.y+parameters.pointB.y));
    gravityAtPoint = ccpMult(ccpNormalize(gravityAtPoint), -10.0f*dt); // nb. vrope uses negative gravity!
    
    // update points with pre-integrated gravity
	[self updateWithParameters:parameters gxdt:gravityAtPoint.x gydt:gravityAtPoint.y];
}

#endif

-(id)initWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB spriteSheet:(CCSpriteBatchNode*)spriteSheetArg {
    return [self initWithPoints:pointA pointB:pointB spriteSheet:spriteSheetArg spriteFrameName:@"longrope.png"];
}

-(id)initWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB spriteSheet:(CCSpriteBatchNode*)spriteSheetArg spriteFrameName:(NSString*)frameName {
	if((self = [super init])) {
		spriteSheet = spriteSheetArg;
        self.ropeFrameName = frameName;
		[self createRope:pointA pointB:pointB];
	}
	return self;
}

- (int) calculatedNumberOfPointsForDistance:(float)distance {
    int segmentFactor = 12; // 16; //12; //increase value to have less segments per rope, decrease to have more segments

    return distance/segmentFactor;
}

- (void) addPointsToRopeForDistance:(float)distance pointA:(CGPoint)pointA andPointB:(CGPoint)pointB {
    int newNumPoints = [self calculatedNumberOfPointsForDistance:distance];
    antiSagHack = 0.1f; //HACK: scale down rope points to cheat sag. set to 0 to disable, max suggested value 0.1
    
    int i = numPoints;
    
    CGPoint startPoint;
    
    if (numPoints == 0) {
        startPoint = pointA;
    } else {
        startPoint = ((VPoint*)[vPoints lastObject]).position;
    }
    
    CGPoint diffVector = ccpSub(pointB,startPoint);
    float newDistance = ccpDistance(startPoint, pointB);
    float multiplier = newDistance / (newNumPoints-1);

    for(;i<newNumPoints;i++) {
        CGPoint tmpVector = ccpAdd(startPoint, ccpMult(ccpNormalize(diffVector),multiplier*i*(1-antiSagHack)));
        VPoint *tmpPoint = [[VPoint alloc] init];
        [tmpPoint setPos:tmpVector.x y:tmpVector.y];
        [vPoints addObject:tmpPoint];
        [tmpPoint release];
    }
    
    i = (numPoints == 0) ? 0 : numPoints - 1;
    
    for(;i<newNumPoints-1;i++) {
        VStick *tmpStick = [[VStick alloc] initWith:[vPoints objectAtIndex:i] pointb:[vPoints objectAtIndex:i+1]];
        [vSticks addObject:tmpStick];
        [tmpStick release];
    }
    if(spriteSheet!=nil) {
        i = (numPoints == 0) ? 0 : numPoints - 1;
        
        for(;i<newNumPoints-1;i++) {
            VPoint *point1 = [[vSticks objectAtIndex:i] getPointA];
            VPoint *point2 = [[vSticks objectAtIndex:i] getPointB];
#if USE_STRETCHED_SPRITE == 0
            CGPoint stickVector = ccpSub(ccp(point1.x,point1.y),ccp(point2.x,point2.y));
            float stickAngle = ccpToAngle(stickVector);
            
            // cocos 1.x
            //CCSprite *tmpSprite = [CCSprite spriteWithBatchNode:spriteSheet rect:CGRectMake(0,0,multiplier,[[[spriteSheet textureAtlas] texture] pixelsHigh]/CC_CONTENT_SCALE_FACTOR())]; // Flightless, retina fix
            
            // cocos 2.x
            CCSprite* tmpSprite = [CCSprite spriteWithTexture:spriteSheet.texture rect:CGRectMake(0,0,multiplier,[[[spriteSheet textureAtlas] texture] pixelsHigh] /CC_CONTENT_SCALE_FACTOR())]; // Flightless, retina fix
            tmpSprite.batchNode = spriteSheet;
            
            ccTexParams params = {GL_LINEAR,GL_LINEAR,GL_REPEAT,GL_REPEAT};
            [tmpSprite.texture setTexParameters:&params];
            [tmpSprite setPosition:ccpMidpoint(ccp(point1.x,point1.y),ccp(point2.x,point2.y))];
            [tmpSprite setRotation:-1 * CC_RADIANS_TO_DEGREES(stickAngle)];
#else
            CCStretchedSpriteLine *tmpSprite = [CCStretchedSpriteLine stretchedSpriteLineFrom:point1.position to:point2.position andSpriteFrameName:self.ropeFrameName];
            tmpSprite.batchNode = spriteSheet;
#endif
            
            [spriteSheet addChild:tmpSprite];
            [ropeSprites addObject:tmpSprite];
        }
    }
    
    numPoints = newNumPoints;
}

-(void)createRope:(CGPoint)pointA pointB:(CGPoint)pointB {
    [self createRopeWithParameters:(RopeParameters){pointA, pointB, ccpDistance(pointA, pointB)}];
}

- (void) createRopeWithParameters:(RopeParameters)parameters {
    vPoints = [[NSMutableArray alloc] init];
    vSticks = [[NSMutableArray alloc] init];
    ropeSprites = [[NSMutableArray alloc] init];
    numPoints = 0;
    
    [self addPointsToRopeForDistance:parameters.length pointA:parameters.pointA andPointB:parameters.pointB];
}

-(void)resetWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB {
	float distance = ccpDistance(pointA,pointB);
    [self resetWithParameters:(RopeParameters){pointA, pointB, distance}];
}

- (void) resetWithParameters:(RopeParameters)parameters {
    CGPoint diffVector = ccpSub(parameters.pointB, parameters.pointA);
    float multiplier = parameters.length / (numPoints - 1);
    
    for(int i=0;i<numPoints;i++) {
        CGPoint tmpVector = ccpAdd(parameters.pointA, ccpMult(ccpNormalize(diffVector),multiplier*i*(1-antiSagHack)));
        VPoint *tmpPoint = [vPoints objectAtIndex:i];
        [tmpPoint setPos:tmpVector.x y:tmpVector.y];
    }
}

-(void)removeSprites {
	for(int i=0;i<numPoints-1;i++) {
#if USE_STRETCHED_SPRITE == 0
        CCSprite *tmpSprite = [ropeSprites objectAtIndex:i];
#else
		CCStretchedSpriteLine *tmpSprite = [ropeSprites objectAtIndex:i];
#endif
		[spriteSheet removeChild:tmpSprite cleanup:YES];
	}
	[ropeSprites removeAllObjects];
}

-(void)updateWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB dt:(float)dt {
    float distance = ccpDistance(pointA,pointB);
    [self updateWithParameters:(RopeParameters){pointA, pointB, distance} dt:dt];
}


- (void) updateWithParameters:(RopeParameters)parameters dt:(float)dt {
    int newNumPoints = [self calculatedNumberOfPointsForDistance:parameters.length];
    
    if (newNumPoints > numPoints) {
        [self addPointsToRopeForDistance:parameters.length pointA:parameters.pointA andPointB:parameters.pointB];
        [self resetWithParameters:parameters];
    }

    //manually set position for first and last point of rope
	[[vPoints objectAtIndex:0] setPos:parameters.pointA.x y:parameters.pointA.y];
	[[vPoints objectAtIndex:numPoints-1] setPos:parameters.pointB.x y:parameters.pointB.y];
	
	//update points, apply gravity
	for(int i=1;i<numPoints-2;i++) {
		[[vPoints objectAtIndex:i] applyGravity:dt];
		[[vPoints objectAtIndex:i] update];
	}
	
	//contract sticks
	int iterations = 4;
	for(int j=0;j<iterations;j++) {
		for(int i=0;i<numPoints-1;i++) {
            [[vSticks objectAtIndex:i] contractAtBeginning:(i == 0) andEnd:(i == (numPoints-2))];
		}
	}
}

-(void)updateWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB gxdt:(float)gxdt gydt:(float)gydt {
	//manually set position for first and last point of rope
    [self updateWithParameters:(RopeParameters){pointA, pointB, ccpDistance(pointA, pointB)} gxdt:gxdt gydt:gydt];
}

- (void) updateWithParameters:(RopeParameters)parameters gxdt:(float)gxdt gydt:(float)gydt {
    [[vPoints objectAtIndex:0] setPos:parameters.pointA.x y:parameters.pointA.y];
    [[vPoints objectAtIndex:numPoints-1] setPos:parameters.pointB.x y:parameters.pointB.y];
    
    //update points, apply pre-integrated gravity
    for(int i=1;i<numPoints-2;i++) {
        [[vPoints objectAtIndex:i] applyGravityxdt:gxdt gydt:gydt];
        [[vPoints objectAtIndex:i] update];
    }
    
    //contract sticks
    int iterations = 4;
    for(int j=0;j<iterations;j++) {
        for(int i=0;i<numPoints-1;i++) {
            [[vSticks objectAtIndex:i] contractAtBeginning:(i == 0) andEnd:(i == (numPoints-2))];
        }
    }
}


-(void)updateSprites {
	if(spriteSheet!=nil) {
		for(int i=0;i<numPoints-1;i++) {
			VPoint *point1 = [[vSticks objectAtIndex:i] getPointA];
			VPoint *point2 = [[vSticks objectAtIndex:i] getPointB];
            
#if USE_STRETCHED_SPRITE == 0
			CGPoint point1_ = ccp(point1.x,point1.y);
			CGPoint point2_ = ccp(point2.x,point2.y);
			float stickAngle = ccpToAngle(ccpSub(point1_,point2_));
            CCSprite *tmpSprite = [ropeSprites objectAtIndex:i];
            [tmpSprite setPosition:ccpMidpoint(point1_,point2_)];
            [tmpSprite setRotation: -CC_RADIANS_TO_DEGREES(stickAngle)];
#else
			CCStretchedSpriteLine *tmpSprite = [ropeSprites objectAtIndex:i];
            tmpSprite.fromPosition = point1.position;
            tmpSprite.toPosition = point2.position;
#endif
		}
	}	
}

/* opengl es 1.1 only*/
-(void)debugDraw {
	//Depending on scenario, you might need to have different Disable/Enable of Client States
	//glDisableClientState(GL_TEXTURE_2D);
	//glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	//glDisableClientState(GL_COLOR_ARRAY);
	//set color and line width for ccDrawLine
    
    ccDrawColor4F(0.0f,0.0f,1.0f,1.0f);
    
    VPoint *pointA = [[vSticks objectAtIndex:0] getPointA];
    ccDrawSolidCircle(pointA.position, 15.0, 18);
    
    ccDrawPoint(ccp(pointA.x,pointA.y));
    
    ccDrawColor4F(0.0f,1.0f,0.0f,1.0f);
    
    VPoint *pointB = [[vSticks objectAtIndex:numPoints-2] getPointB];
    ccDrawSolidCircle(pointB.position, 15.0, 18);
    
    ccDrawColor4F(1.0f,1.0f,1.0f,1.0f);
    
    glLineWidth(5.0);
	for(int i=0;i<numPoints-1;i++) {
		//"debug" draw
		VPoint *pointA = [[vSticks objectAtIndex:i] getPointA];
		VPoint *pointB = [[vSticks objectAtIndex:i] getPointB];
		ccDrawPoint(ccp(pointA.x,pointA.y));
		ccDrawPoint(ccp(pointB.x,pointB.y));
		ccDrawLine(ccp(pointA.x,pointA.y),ccp(pointB.x,pointB.y));
	}
    
	//restore to white and default thickness
	ccDrawColor4F(1.0f,1.0f,1.0f,1.0f);

	glLineWidth(1.0);
    
    glBlendFunc(CC_BLEND_SRC, CC_BLEND_DST);
	//glEnableClientState(GL_TEXTURE_2D);
	//glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	//glEnableClientState(GL_COLOR_ARRAY);
}

-(void)dealloc {
    /*
	for(int i=0;i<numPoints;i++) {
		[[vPoints objectAtIndex:i] release];
		if(i!=numPoints-1)
			[[vSticks objectAtIndex:i] release];
	}
	[vPoints removeAllObjects];
	[vSticks removeAllObjects];
    */
    
    //[self removeSprites];
    [ropeSprites release];
    
    self.ropeFrameName = nil;
    
	[vPoints release];
	[vSticks release];
	[super dealloc];
}

@end
