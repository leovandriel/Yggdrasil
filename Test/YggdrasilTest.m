//
//  YggdrasilTests.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "YGScanner.h"
#import "YGLabelers.h"
#import "YGFormat.h"


@interface YggdrasilTest : XCTestCase
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
    core.labeler = [[YGBlockLabeler alloc] initWithName:@"" rect:NSMakeRect(-1, -1, 2, 2) async:NO block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        XCTAssertTrue(finished, @"");
        XCTAssertEqualObjects([self flat:node], @"N", @"");
        done = YES;
    }];
    XCTAssertTrue(done, @"");
}

- (void)testOneDepth
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 0;
    core.maxDepth = 1;
    core.labeler = [[YGBlockLabeler alloc] initWithName:@"" rect:NSMakeRect(-1, -1, 2, 2) async:NO block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        XCTAssertTrue(finished, @"");
        XCTAssertEqualObjects([self flat:node], @"[N,0,N,0]", @"");
        done = YES;
    }];
    XCTAssertTrue(done, @"");
}

- (void)testTwoDepth
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 0;
    core.maxDepth = 2;
    core.labeler = [[YGBlockLabeler alloc] initWithName:@"" rect:NSMakeRect(-1, -1, 2, 2) async:NO block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        XCTAssertTrue(finished, @"");
        XCTAssertEqualObjects([self flat:node], @"[N,[0,P,0,P],N,[0,P,0,P]]", @"");
        done = YES;
    }];
    XCTAssertTrue(done, @"");
}

- (void)testTwoDepthMin
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 1;
    core.maxDepth = 2;
    core.labeler = [[YGBlockLabeler alloc] initWithName:@"" rect:NSMakeRect(-1, -1, 2, 2) async:NO block:^NSString *(NSPoint p) {
        return p.x > 0 ? @"P" : (p.x < 0 ? @"N" : @"0");
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        XCTAssertTrue(finished, @"");
        XCTAssertEqualObjects([self flat:node], @"[N,[0,P,0,P],N,[0,P,0,P]]", @"");
        done = YES;
    }];
    XCTAssertTrue(done, @"");
}

- (void)testCircle
{
    YGScanner *core = [[YGScanner alloc] init];
    core.minDepth = 3;
    core.maxDepth = 3;
    core.labeler = [[YGBlockLabeler alloc] initWithName:@"" rect:NSMakeRect(-1, -1, 2, 2) async:NO block:^NSString *(NSPoint p) {
        return p.x * p.x + p.y * p.y < 1 ? @"0" : @" ";
    }];
    YGNode *node = [[YGNode alloc] init];
    __block BOOL done = NO;
    [core processNode:node block:^(BOOL finished) {
        XCTAssertTrue(finished, @"");
        XCTAssertEqual((int)[self flat:node].length, 105, @"");
        done = YES;
    }];
    XCTAssertTrue(done, @"");
}

- (void)testTextFormat
{
    NSData *data = [YGFormat textDataWithNode:[self node:@"[N,[,P,,P],N,[,P,,P]]"]];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(text, @"YGG:txt:2,4,P,N,[2,[,1,,0],2,[,1,,0]]", @"");
    NSString *plain = [self flat:[YGFormat nodeWithData:data]];
    XCTAssertEqualObjects(plain, @"[N,[,P,,P],N,[,P,,P]]", @"");
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
    XCTAssertEqualObjects(data.description, @"<80818283 84ff4080 7fff2040 00>", @"");
    NSUInteger index = 0;
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 0Lu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 1Lu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 2Lu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 3Lu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 4Lu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 0x7FLu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 0x80Lu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 0x3FFFLu, @"");
    XCTAssertEqual([YGFormat parseValueFromData:data index:&index], 0x4000Lu, @"");
}

- (void)testBinaryFormat
{
    NSData *data = [YGFormat binaryDataWithNode:[self node:@"[N,[,P,,P],N,[,P,,P]]"]];
    NSLog(@"%.*s", (int)data.length, data.bytes);
    XCTAssertEqualObjects(data.description, @"<5947473a 626e323a 10000002 10000004 1000000d 10000007 50004e00 bb822181 822181>", @"");
    NSString *plain = [self flat:[YGFormat nodeWithData:data]];
    XCTAssertEqualObjects(plain, @"[N,[,P,,P],N,[,P,,P]]", @"");
}

@end
