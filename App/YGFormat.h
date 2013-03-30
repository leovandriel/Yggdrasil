//
//  YGFormat.h
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGScanner.h"


@interface YGFormat : NSObject

+ (NSData *)dataWithNode:(YGNode *)node;
+ (YGNode *)nodeWithData:(NSData *)data;

+ (NSData *)plainDataWithNode:(YGNode *)node;
+ (NSData *)textDataWithNode:(YGNode *)node;

@end
