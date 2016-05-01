//
//  BNRCustomSegue.m
//  CustomSegue
//
//  Created by Daniel Campbell on 3/6/16.
//  Copyright © 2016 Daniel Campbell. All rights reserved.
//

#import "BNRCustomSegue.h"
#import <QuartzCore/QuartzCore.h>
NSString *BNRCustomSegueReverse = @"BNRCustomSegueReverse";
NSString *BNRCustomSegueForward = @"BNRCustomSegueForward";

@interface UIView (contents)

-(UIImage *)bnrImageContents;

@end


@implementation UIView (contents)

-(UIImage *)bnrImageContents {
    CGSize mySize = [self bounds].size;
    UIGraphicsBeginImageContext(mySize);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end


@interface BNRCustomSegue ()

@property(nonatomic, strong) CALayer *overlay;

@end


@implementation BNRCustomSegue

@synthesize overlay = _overlay;

#pragma mark - Init

-(id)initWithIdentifier:(NSString *)identifier
                 source:(UIViewController *)source
            destination:(UIViewController *)destination
{
    if (self = [super initWithIdentifier:identifier source:source destination:destination]) {
        UINavigationController *navController = source.navigationController;
        
        CGRect bounds = navController.view.bounds;
        bounds.origin.x = 0.0f;
        bounds.origin.y = 0.0f;
        
        CALayer *overlayLayer = [CALayer layer];
        overlayLayer.frame = bounds;
        _overlay = overlayLayer;
    }
    
    return self;
}

-(void)perform
{
    UIViewController *source = self.sourceViewController;
    UIViewController *destination = self.destinationViewController;
    
    UINavigationController *navController = source.navigationController;
    
    // Grab the image of the old view and use it in the overlay layer
    UIImage *sourceImage = [navController.view bnrImageContents];
    self.overlay.contents = (id)sourceImage.CGImage;
    
    // Put the new view controller on the stack
    if ([self.identifier isEqualToString:BNRCustomSegueReverse]) {
        // Going from back to front, clear out the navigation stack to avoid growing forever
        [navController popViewControllerAnimated:NO];
    } else {
        [navController pushViewController:destination animated:NO];
    }
    
    // Grab the image of the new view, which we will transition overlay to
    UIImage *destImage = [navController.view bnrImageContents];
    
    // Slice the images in half
    CGRect topRect = CGRectMake(0.0, 0.0, destImage.size.width, destImage.size.height/2.0);
    CGImageRef topImage = CGImageCreateWithImageInRect(sourceImage.CGImage, topRect);
    self.overlay.frame = topRect;
    self.overlay.contents = (__bridge id)topImage;
    CGImageRelease(topImage);
    self.overlay.anchorPoint = CGPointMake(0.5, 1.0);
    self.overlay.position = CGPointMake(destImage.size.width/2.0, destImage.size.height/2.0);
    self.overlay.doubleSided = NO;

    CGRect bottomRect = CGRectMake(0.0, destImage.size.height/2.0, destImage.size.width, destImage.size.height/2.0);
    CGImageRef bottomImage = CGImageCreateWithImageInRect(sourceImage.CGImage, bottomRect);
    CALayer *bottomLayer = [CALayer layer];
    bottomLayer.frame = bottomRect;
    bottomLayer.contents = (__bridge id)bottomImage;
    CGImageRelease(bottomImage);
    
    CGImageRef backImage = CGImageCreateWithImageInRect(destImage.CGImage, bottomRect);
    CALayer *backLayer = [CALayer layer];
    backLayer.frame = CGRectMake(0.0, -destImage.size.height/2.0, destImage.size.width, destImage.size.height/2.0);
    backLayer.contents = (__bridge id)backImage;
    CGImageRelease(backImage);
    backLayer.anchorPoint = CGPointMake(0.5, 0.0);
    backLayer.position = CGPointMake(destImage.size.width/2.0, destImage.size.height/2.0);
    backLayer.doubleSided = NO;
    
    // Shadow
    CAGradientLayer *gradientMask = [CAGradientLayer layer];
    gradientMask.frame = self.overlay.bounds;
    gradientMask.colors = @[(id)[UIColor clearColor].CGColor,
                            (id)[UIColor colorWithRed:0 green:0 blue:0 alpha:0.1].CGColor];
    
    // Now that we have the images, add the temporary overlay layer
    [navController.view.layer addSublayer:self.overlay];
    [navController.view.layer addSublayer:backLayer];
    [navController.view.layer addSublayer:bottomLayer];
    [self.overlay addSublayer:gradientMask];
    
    // Perspective Transform
    CATransform3D perspectiveTransform = CATransform3DIdentity;
    perspectiveTransform.m34 = -1.0/1000;
    [navController.view.layer setSublayerTransform:perspectiveTransform];
    
    CGFloat flipDuration = 0.5f;
    NSString *animName = @"segue";
    
    // Housekeeping when the transition completes
    [CATransaction setCompletionBlock:^{
        [self.overlay removeAnimationForKey:animName];
        navController.view.userInteractionEnabled = YES;
        
        [self.overlay removeFromSuperlayer];
        self.overlay = nil;
        
        [bottomLayer removeAnimationForKey:animName];
        [bottomLayer removeFromSuperlayer];
        
        [backLayer removeAnimationForKey:animName];
        [backLayer removeFromSuperlayer];
    }];
    
    // Animation (disable user interaction at start)
    navController.view.userInteractionEnabled = NO;
    [CATransaction begin];
    {
        [CATransaction setAnimationDuration:flipDuration];
        {
            CABasicAnimation *frontFold = [CABasicAnimation animationWithKeyPath:@"transform.rotation.x"];
            frontFold.duration = flipDuration;
            frontFold.fromValue = [NSNumber numberWithFloat:0.0];
            frontFold.toValue = [NSNumber numberWithFloat:-M_PI];
            // Leave the animation up on completion; without this, you can get a little flicker if the user taps quickly on the buttion
            frontFold.removedOnCompletion = NO;
            [self.overlay addAnimation:frontFold forKey:animName];
            
            CABasicAnimation *backFold = [CABasicAnimation animationWithKeyPath:@"transform.rotation.x"];
            backFold.duration = flipDuration;
            backFold.fillMode = kCAFillModeForwards;
            backFold.fromValue = [NSNumber numberWithFloat:M_PI];
            backFold.toValue = [NSNumber numberWithFloat:0.0f];
            backFold.removedOnCompletion = NO;
            [backLayer addAnimation:backFold forKey:animName];
        }
    }
    [CATransaction commit];
}

@end
