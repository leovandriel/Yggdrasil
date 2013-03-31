//
//  YGFormat.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGFormat.h"

static NSString * const YGFormatPlainPrefix = @"YGG:pln:";
static NSString * const YGFormatTextPrefix = @"YGG:txt:";
static NSString * const YGFormatBinaryPrefix = @"YGG:bin:";


@implementation YGFormat


#pragma mark - Format support

+ (NSData *)dataWithNode:(NSMutableArray *)node
{
    return [self binaryDataWithNode:node];
}

+ (NSMutableArray *)nodeWithData:(NSData *)data
{
    NSString *format = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 8)] encoding:NSUTF8StringEncoding];
    if ([format isEqualToString:YGFormatPlainPrefix]) return [self nodeWithPlainData:data];
    if ([format isEqualToString:YGFormatTextPrefix]) return [self nodeWithTextData:data];
    if ([format isEqualToString:YGFormatBinaryPrefix]) return [self nodeWithBinaryData:data];
    return [self nodeWithPlainData:data];
}


#pragma mark - Original JSON-based format

+ (NSData *)plainDataWithNode:(YGNode *)node
{
    NSData *data = node ? [NSJSONSerialization dataWithJSONObject:node options:0 error:nil] : nil;
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    string = [string stringByReplacingOccurrencesOfString:@"],[" withString:@"]["];
    string = [string stringByReplacingOccurrencesOfString:@"," withString:@"_"];
    string = [string stringByReplacingOccurrencesOfString:@"][" withString:@"],["];
    string = [string stringByReplacingOccurrencesOfString:@"[\"" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"\"]" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"[]" withString:@""];
    string = [YGFormatPlainPrefix stringByAppendingString:string];
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

+ (YGNode *)nodeWithPlainData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([string hasPrefix:YGFormatPlainPrefix]) string = [string substringFromIndex:YGFormatPlainPrefix.length];
    string = [string stringByReplacingOccurrencesOfString:@"([^,\\[\\]]+)" withString:@"[\"$1\"]" options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
    string = [string stringByReplacingOccurrencesOfString:@"[," withString:@"[[\"\"],"];
    string = [string stringByReplacingOccurrencesOfString:@",," withString:@",[\"\"],"];
    string = [string stringByReplacingOccurrencesOfString:@",," withString:@",[\"\"],"];
    string = [string stringByReplacingOccurrencesOfString:@",]" withString:@",[\"\"]]"];
    return [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
}


#pragma mark - Text-based version of binary format

+ (NSData *)textDataWithNode:(YGNode *)node
{
    NSMutableString *string = @"".mutableCopy;
    [string appendString:YGFormatTextPrefix];
    NSString *last = nil;
    NSMutableDictionary *countForLabel = @{}.mutableCopy;
    [self collectLabelsInNode:node labels:countForLabel last:&last];
    NSArray *labels = [countForLabel keysSortedByValueUsingSelector:@selector(compare:)];
    [string appendFormat:@"%lu,", labels.count];
    NSUInteger indexLength = labels.count;
    for (NSString *label in labels) indexLength += label.length;
    [string appendFormat:@"%lu,", indexLength];
    NSMutableDictionary *indexForLabel = @{}.mutableCopy;
    NSUInteger i = 1;
    for (NSString *label in labels.reverseObjectEnumerator) {
        indexForLabel[label] = @(i++);
        [string appendString:[label stringByReplacingOccurrencesOfString:@"," withString:@""]];
        [string appendString:@","];
    }
    last = nil;
    [self appendNode:node string:string labels:indexForLabel last:&last];
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

+ (void)collectLabelsInNode:(YGNode *)node labels:(NSMutableDictionary *)labels last:(NSString **)last
{
    if (node.count == 4) {
        for (id n in node) {
            [self collectLabelsInNode:n labels:labels last:last];
        }
    } else {
        NSString *label = node[0];
        if (label.length && ![label isEqualToString:*last]) {
            labels[label] = @([labels[label] unsignedIntegerValue] + 1);
            *last = label;
        }
    }
}

+ (void)appendNode:(YGNode *)node string:(NSMutableString *)string labels:(NSDictionary *)labels last:(NSString **)last
{
    if (node.count == 4) {
        [string appendString:@"["];
        BOOL first = YES;
        for (id n in node) {
            if (first) first = NO; else [string appendString:@","];
            [self appendNode:n string:string labels:labels last:last];
        }
        [string appendString:@"]"];
    } else {
        NSString *label = node[0];
        if (!label.length) {
            [string appendString:@""];
        } else if ([label isEqualToString:*last]) {
            [string appendString:@"0"];
        } else {
            [string appendFormat:@"%lu", [labels[label] unsignedIntegerValue]];
            *last = label;
        }
    }
}

+ (YGNode *)nodeWithTextData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (![string hasPrefix:YGFormatTextPrefix]) return nil;
    NSUInteger a = YGFormatTextPrefix.length;
    NSUInteger b = [string rangeOfString:@"," options:0 range:NSMakeRange(a, string.length - a)].location + 1;
    NSUInteger c = [string rangeOfString:@"," options:0 range:NSMakeRange(b, string.length - b)].location + 1;
    NSUInteger length = [[string substringWithRange:NSMakeRange(b, c - b - 1)] integerValue];
    NSArray *labels = [[string substringWithRange:NSMakeRange(c, length)] componentsSeparatedByString:@","];
    NSUInteger index = c + length - 1;
    NSString *last = nil;
    YGNode *result = [self nodeWithString:string index:&index labels:labels last:&last];
    return result;
}

+ (YGNode *)nodeWithString:(NSString *)string index:(NSUInteger *)index labels:(NSArray *)labels last:(NSString **)last
{
    switch ([string characterAtIndex:++*index]) {
        case '[': {
            YGNode *result = @[[self nodeWithString:string index:index labels:labels last:last],[self nodeWithString:string index:index labels:labels last:last],[self nodeWithString:string index:index labels:labels last:last],[self nodeWithString:string index:index labels:labels last:last]].mutableCopy;
            (*index)++;
            return result;
        }
        case ',': case ']': return @[@""].mutableCopy;
        case '0': (*index)++; return @[*last].mutableCopy;
        default: {
            NSRange r = [string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@",]"] options:0 range:NSMakeRange(*index, string.length - *index)], range = NSMakeRange(*index, r.location - *index);
            NSUInteger i = [[string substringWithRange:range] integerValue];
            if (i) {
                (*index) += range.length;
                NSString *label = labels[i - 1];
                *last = label;
                return @[label].mutableCopy;
            }
        }
    }
    return nil;
}


#pragma mark - Binary format

+ (NSData *)binaryDataWithNode:(YGNode *)node
{
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendData:[YGFormatBinaryPrefix dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *last = nil;
    NSMutableDictionary *countForLabel = @{}.mutableCopy;
    [self collectLabelsInNode:node labels:countForLabel last:&last];
    NSArray *labels = [countForLabel keysSortedByValueUsingSelector:@selector(compare:)];
    [self appendValue:labels.count data:data];
    NSMutableDictionary *indexForLabel = @{}.mutableCopy;
    unsigned char zero = 0;
    NSUInteger i = 1;
    NSMutableData *indexData = [[NSMutableData alloc] init];
    for (NSString *label in labels.reverseObjectEnumerator) {
        indexForLabel[label] = @(i++);
        [indexData appendData:[label dataUsingEncoding:NSUTF8StringEncoding]];
        [indexData appendBytes:&zero length:1];
    }
    [self appendValue:indexData.length data:data];
    [data appendData:indexData];
    last = nil;
    [self appendNode:node data:data labels:indexForLabel last:&last];
    return data;
}

+ (char)appendNode:(YGNode *)node data:(NSMutableData *)data labels:(NSDictionary *)labels last:(NSString **)last
{
    if (node.count == 4) {
        unsigned char code = 0;
        NSUInteger index = data.length;
        [data appendBytes:&code length:1];
        for (YGNode *n in node) {
            code = (code << 2) + [self appendNode:n data:data labels:labels last:last];
        }
        [data replaceBytesInRange:NSMakeRange(index, 1) withBytes:&code];
        return 3;
    } else {
        NSString *label = node[0];
        if (!label.length) return 0;
        if ([label isEqualToString:*last]) return 1;
        [self appendValue:[labels[label] unsignedIntegerValue] data:data];
        *last = label;
        return 2;
    }
}

+ (YGNode *)nodeWithBinaryData:(NSData *)data
{
    if (data.length < 8 || ![[[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 8)] encoding:NSUTF8StringEncoding] isEqualToString:YGFormatBinaryPrefix]) return nil;
    NSUInteger index = YGFormatBinaryPrefix.length;
    NSUInteger count = [self parseValueFromData:data index:&index];
    [self parseValueFromData:data index:&index];
    NSMutableArray *labels = @[].mutableCopy;
    for (NSUInteger i = 0; i < count; i++) {
        [labels addObject:[self parseStringFromData:data index:&index]];
    }
    NSString *last = nil;
    YGNode *result = [self nodeWithData:data index:&index labels:labels last:&last];
    return result;
}

+ (YGNode *)nodeWithData:(NSData *)data index:(NSUInteger *)index labels:(NSArray *)labels last:(NSString **)last
{
    unsigned char code = 0;
    [data getBytes:&code range:NSMakeRange(*index, 1)]; ++*index;
    YGNode *result = @[].mutableCopy;
    for (NSUInteger i = 0; i < 4; i++) {
        switch (code & 0xC0) {
            case 0x00: [result addObject:@[@""].mutableCopy]; break;
            case 0x80: *last = labels[[self parseValueFromData:data index:index] - 1];
            case 0x40: [result addObject:@[*last].mutableCopy]; break;
            case 0xC0: [result addObject:[self nodeWithData:data index:index labels:labels last:last]]; break;
        }
        code <<= 2;
    }
    return result;
}

+ (void)appendValue:(NSUInteger)value data:(NSMutableData *)data
{
    if (value < 0x80) {
        value += 0x80;
        [data appendBytes:&value length:1];
    } else if (value < 0x4000) {
        value += 0x4000;
        [data appendBytes:(unsigned char *)&value + 1 length:1];
        [data appendBytes:(unsigned char *)&value length:1];
    } else if (value < 0x200000) {
        value += 0x200000;
        [data appendBytes:(unsigned char *)&value + 2 length:1];
        [data appendBytes:(unsigned char *)&value + 1 length:1];
        [data appendBytes:(unsigned char *)&value length:1];
    } else if (value < 0x10000000) {
        value += 0x10000000;
        [data appendBytes:(unsigned char *)&value + 3 length:1];
        [data appendBytes:(unsigned char *)&value + 2 length:1];
        [data appendBytes:(unsigned char *)&value + 1 length:1];
        [data appendBytes:(unsigned char *)&value length:1];
    }
}

+ (NSUInteger)parseValueFromData:(NSData *)data index:(NSUInteger *)index
{
    unsigned char c = 0;
    [data getBytes:&c range:NSMakeRange(*index, 1)];
    NSUInteger result = 0;
    if (c >= 0x80) {
        [data getBytes:&result range:NSMakeRange((*index)++, 1)];
        return result - 0x80;
    } else if (c >= 0x40) {
        [data getBytes:(unsigned char *)&result + 1 range:NSMakeRange((*index)++, 1)];
        [data getBytes:(unsigned char *)&result range:NSMakeRange((*index)++, 1)];
        return result - 0x4000;
    } else if (c >= 0x20) {
        [data getBytes:(unsigned char *)&result + 2 range:NSMakeRange((*index)++, 1)];
        [data getBytes:(unsigned char *)&result + 1 range:NSMakeRange((*index)++, 1)];
        [data getBytes:(unsigned char *)&result range:NSMakeRange((*index)++, 1)];
        return result - 0x200000;
    } else if (c >= 0x10) {
        [data getBytes:(unsigned char *)&result + 3 range:NSMakeRange((*index)++, 1)];
        [data getBytes:(unsigned char *)&result + 2 range:NSMakeRange((*index)++, 1)];
        [data getBytes:(unsigned char *)&result + 1 range:NSMakeRange((*index)++, 1)];
        [data getBytes:(unsigned char *)&result range:NSMakeRange((*index)++, 1)];
        return result - 0x10000000;
    }
    return 0;
}

+ (NSString *)parseStringFromData:(NSData *)data index:(NSUInteger *)index
{
    const char *bytes = (const char *)data.bytes + *index;
    for (NSUInteger i = 0; i + *index < data.length; i++, bytes++) {
        if (*bytes == '\0') {
            *index += i + 1;
            return [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(*index - i - 1, i)] encoding:NSUTF8StringEncoding];
        }
    }
    return nil;
}

@end
