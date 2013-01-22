//
//  YggdrasilTests.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "YGScanner.h"
#import "YGLabelers.h"


@interface YggdrasilTest : SenTestCase
@end
@implementation YggdrasilTest

- (NSString *)flat:(id)object
{
    NSString *result = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:object options:0 error:nil] encoding:NSUTF8StringEncoding];
    result = [result stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    return result;
}

- (void)testNoDepth
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 0;
    core.maxDepth = 0;
    core.labeler = [[YGBlockLabeler alloc] initWithRect:NSMakeRect(-1, -1, 2, 2) block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        STAssertTrue(finished, @"");
        STAssertEqualObjects([self flat:node], @"[N]", @"");
        done = YES;
    }];
    STAssertTrue(done, @"");
}

- (void)testOneDepth
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 0;
    core.maxDepth = 1;
    core.labeler = [[YGBlockLabeler alloc] initWithRect:NSMakeRect(-1, -1, 2, 2) block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        STAssertTrue(finished, @"");
        STAssertEqualObjects([self flat:node], @"[[N],[0],[N],[0]]", @"");
        done = YES;
    }];
    STAssertTrue(done, @"");
}

- (void)testTwoDepth
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 0;
    core.maxDepth = 2;
    core.labeler = [[YGBlockLabeler alloc] initWithRect:NSMakeRect(-1, -1, 2, 2) block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        STAssertTrue(finished, @"");
        STAssertEqualObjects([self flat:node], @"[[N],[[0],[P],[0],[P]],[N],[[0],[P],[0],[P]]]", @"");
        done = YES;
    }];
    STAssertTrue(done, @"");
}

- (void)testTwoDepthMin
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 1;
    core.maxDepth = 2;
    core.labeler = [[YGBlockLabeler alloc] initWithRect:NSMakeRect(-1, -1, 2, 2) block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        STAssertTrue(finished, @"");
        STAssertEqualObjects([self flat:node], @"[[N],[[0],[P],[0],[P]],[N],[[0],[P],[0],[P]]]", @"");
        done = YES;
    }];
    STAssertTrue(done, @"");
}

- (void)testCircle
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 3;
    core.maxDepth = 3;
    core.labeler = [[YGBlockLabeler alloc] initWithRect:NSMakeRect(-1, -1, 2, 2) block:^NSString *(NSPoint p) {
        return p.x * p.x + p.y * p.y < 1 ? @"0" : @" ";
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        STAssertTrue(finished, @"");
        STAssertEquals((int)[self flat:node].length, 185, @"");
        done = YES;
    }];
    STAssertTrue(done, @"");
}


@end
