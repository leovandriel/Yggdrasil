//
//  YGController.h
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGScanner.h"


@interface YGController : NSObject <YGProgressDelegate>

- (void)setupWithLabelers:(NSArray *)labelers min:(NSUInteger)min max:(NSUInteger)max sub:(NSUInteger)sub;
- (void)stop;

@end
