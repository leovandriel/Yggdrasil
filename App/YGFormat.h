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
+ (NSData *)binaryDataWithNode:(YGNode *)node;

+ (void)appendValue:(NSUInteger)value data:(NSMutableData *)data;
+ (NSUInteger)parseValueFromData:(NSData *)data index:(NSUInteger *)index;

@end
