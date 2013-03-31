//
//  YggdrasilTests.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "YGScanner.h"
#import "YGLabelers.h"
#import "YGFormat.h"


@interface YggdrasilTest : SenTestCase
@end
@implementation YggdrasilTest

- (NSString *)flat:(YGNode *)node
{
    return [[[NSString alloc] initWithData:[YGFormat plainDataWithNode:node] encoding:NSUTF8StringEncoding] substringFromIndex:8];
}

- (YGNode *)node:(NSString *)string
{
    return [YGFormat nodeWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
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
        STAssertEqualObjects([self flat:node], @"N", @"");
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
        STAssertEqualObjects([self flat:node], @"[N,0,N,0]", @"");
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
        STAssertEqualObjects([self flat:node], @"[N,[0,P,0,P],N,[0,P,0,P]]", @"");
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
        STAssertEqualObjects([self flat:node], @"[N,[0,P,0,P],N,[0,P,0,P]]", @"");
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
        STAssertEquals((int)[self flat:node].length, 105, @"");
        done = YES;
    }];
    STAssertTrue(done, @"");
}

- (void)testTextFormat
{
    NSData *data = [YGFormat textDataWithNode:[self node:@"[N,[,P,,P],N,[,P,,P]]"]];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    STAssertEqualObjects(text, @"YGG:txt:2,4,P,N,[2,[,1,,0],2,[,1,,0]]", @"");
    NSString *plain = [self flat:[YGFormat nodeWithData:data]];
    STAssertEqualObjects(plain, @"[N,[,P,,P],N,[,P,,P]]", @"");
}

- (void)testBinaryValues
{
    NSMutableData *data = [[NSMutableData alloc] init];
    [YGFormat appendValue:0 data:data];
    [YGFormat appendValue:1 data:data];
    [YGFormat appendValue:2 data:data];
    [YGFormat appendValue:3 data:data];
    [YGFormat appendValue:4 data:data];
    [YGFormat appendValue:0x7F data:data];
    [YGFormat appendValue:0x80 data:data];
    [YGFormat appendValue:0x3FFF data:data];
    [YGFormat appendValue:0x4000 data:data];
    STAssertEqualObjects(data.description, @"<80818283 84ff4080 7fff2040 00>", @"");
    NSUInteger index = 0;
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 0Lu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 1Lu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 2Lu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 3Lu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 4Lu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 0x7FLu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 0x80Lu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 0x3FFFLu, @"");
    STAssertEquals([YGFormat parseValueFromData:data index:&index], 0x4000Lu, @"");
}

- (void)testBinaryFormat
{
    NSData *data = [YGFormat binaryDataWithNode:[self node:@"[N,[,P,,P],N,[,P,,P]]"]];
    NSLog(@"%.*s", (int)data.length, data.bytes);
    STAssertEqualObjects(data.description, @"<5947473a 62696e3a 82845000 4e00bb82 21818221 81>", @"");
    NSString *plain = [self flat:[YGFormat nodeWithData:data]];
    STAssertEqualObjects(plain, @"[N,[,P,,P],N,[,P,,P]]", @"");
}

@end
