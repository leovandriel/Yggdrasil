//
//  YGFormat.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGFormat.h"

static NSString * const YGFormatPlainPrefix = @"YGG:pln:";
static NSString * const YGFormatTextPrefix = @"YGG:txt:";


@implementation YGFormat


#pragma mark - Format support

+ (NSData *)dataWithNode:(NSMutableArray *)node
{
    // use default
    return [self textDataWithNode:node];
}

+ (NSMutableArray *)nodeWithData:(NSData *)data
{
    NSString *format = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 8)] encoding:NSUTF8StringEncoding];
    if ([format isEqualToString:YGFormatPlainPrefix]) return [self nodeWithPlainData:data];
    if ([format isEqualToString:YGFormatTextPrefix]) return [self nodeWithTextData:data];
    // assume old format
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
//    for (NSString *label in labels) NSLog(@"%@ -> %@", label, countForLabel[label]);
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

@end
