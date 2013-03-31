//
//  YGController.h
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGScanner.h"


@interface YGController : NSObject <YGProgressDelegate>

- (void)setupWithLabelers:(NSArray *)labelers depth:(NSUInteger)depth;
- (void)stop;

@end
