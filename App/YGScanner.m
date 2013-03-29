//
//  YGScanner.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGScanner.h"


void dispatch_if_async(dispatch_queue_t queue, dispatch_block_t block);

@implementation YGScanner {
    NSMutableDictionary *_cache;
    NSDate *_lastSave;
    BOOL _cancelled;
}


#pragma mark - Object life cycle

- (id)initWithLabeler:(id<YGLabeler>)labeler minDepth:(NSUInteger)minDepth maxDepth:(NSUInteger)maxDepth subSample:(NSUInteger)subSample
{
    self = [super init];
    if (self) {
        _queue = dispatch_get_current_queue();
        _useCaching = YES;
        _labeler = labeler;
        _minDepth = minDepth;
        _maxDepth = maxDepth;
        _subSample = subSample;
    }
    return self;
}


#pragma mark - Caching

+ (NSString *)tempDir
{
    NSString *result = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (paths.count) {
        result = [paths[0] stringByAppendingPathComponent:@"Yggdrasil"];
        [NSFileManager.defaultManager createDirectoryAtPath:result withIntermediateDirectories:NO attributes:nil error:nil];
    }
    return result;
}

+ (NSString *)cachePathWithName:(NSString *)name
{
    return [[self.class tempDir] stringByAppendingPathComponent:[name stringByAppendingString:@".cache"]];;
}

- (void)loadCache
{
    _cache = @{}.mutableCopy;
    if (_useCaching && _labeler.name.length) {
        NSString *path = [self.class cachePathWithName:_labeler.name];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data.length) {
            _cache = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        }
        _lastSave = NSDate.date;
    }
}

- (void)saveCache
{
    if (_useCaching && _labeler.name.length) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:_cache options:0 error:nil];
        if (data.length) {
            NSString *path = [self.class cachePathWithName:_labeler.name];
            [data writeToFile:path atomically:NO];
            _lastSave = NSDate.date;
        }
    }
}

- (void)clearCache
{
    _cache = @{}.mutableCopy;
    [self saveCache];
}

+ (void)clearCacheWithName:(NSString *)name
{
    if (name.length) {
        NSString *path = [self.class cachePathWithName:name];
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}


#pragma mark - Labels and caching

- (void)labelAtPoint:(NSPoint)point block:(void(^)(NSString *))block
{
    NSString *lookup = [NSString stringWithFormat:@"%.6f,%.6f", point.x, point.y];
    NSString *result = _cache[lookup];
    if (!result) {
        [_labeler labelAtPoint:point block:^(NSString *label) {
            if (label) {
                _cache[lookup] = label;
                if (-[_lastSave timeIntervalSinceNow] > 60) [self saveCache];
            }
            if (block) block(label);
        }];
    } else {
        dispatch_if_async(_queue, ^{
            if (block) block(result);
        });
    }
}

- (void)labelsAt:(NSArray *)points results:(NSArray *)results block:(void(^)(NSArray *))block
{
    if (points.count) {
        NSPoint p = [points[0] pointValue];
        [self labelAtPoint:p block:^(NSString *label) {
            if (label) {
                NSArray *p = [points subarrayWithRange:NSMakeRange(1, points.count - 1)];
                NSArray *r = [results arrayByAddingObject:label];
                [self labelsAt:p results:r block:block];
            } else {
                if (block) block(nil);
            }
        }];
    } else {
        if (block) block(results);
    }
}


#pragma mark - Processing (scanning)

- (void)processNode:(YGNode *)node block:(void(^)(BOOL))block
{
    _cancelled = NO;
    _running = YES;
    [self loadCache];
    [self processNode:node rect:_labeler.rect depth:0 same:0 block:^(BOOL finished) {
        [self saveCache];
        _running = NO;
        dispatch_if_async(_queue, ^{
            if (block) block(finished);
        });
    }];
}

- (NSString *)combineLabels:(NSArray *)labels
{
    BOOL has[4] = {[labels[0] length] > 0, [labels[1] length] > 0, [labels[2] length] > 0, [labels[3] length] > 0};
    if (has[0] && [labels[0] isEqualToString:labels[1]]) return labels[1];
    if (has[2] && [labels[2] isEqualToString:labels[3]]) return labels[3];
    if (has[0] && [labels[0] isEqualToString:labels[2]]) return labels[2];
    if (has[3] && [labels[3] isEqualToString:labels[1]]) return labels[1];
    if (has[0] && [labels[0] isEqualToString:labels[3]]) return labels[3];
    if (has[1] && [labels[1] isEqualToString:labels[2]]) return labels[2];
    if (has[3]) return labels[3];
    if (has[2]) return labels[2];
    if (has[1]) return labels[1];
    if (has[0]) return labels[0];
    return @"";
}

- (void)processNode:(YGNode *)node rect:(NSRect)rect depth:(NSUInteger)depth same:(NSUInteger)same block:(void(^)(BOOL finished))block
{
    if (_cancelled) {
        if (block) block(NO);
        return;
    }
    NSArray *points = @[
       [NSValue valueWithPoint:NSMakePoint(rect.origin.x, rect.origin.y)],
       [NSValue valueWithPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y)],
       [NSValue valueWithPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height)],
       [NSValue valueWithPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)],
    ];
    [self labelsAt:points results:@[] block:^(NSArray *labels) {
        if (!labels) {
            if (block) block(NO);
            return;
        }
        if (depth >= _maxDepth) {
            [_delegate scannerAtRect:rect depth:depth];
            node.array = @[[self combineLabels:labels]];
            if (block) block(YES);
            return;
        }
        BOOL equal = [labels[0] isEqualToString:labels[1]] && [labels[1] isEqualToString:labels[2]] && [labels[2] isEqualToString:labels[3]];
        if (equal && same >= _subSample && depth > _minDepth) {
            [_delegate scannerAtRect:rect depth:depth];
            node.array = @[equal ? labels[0] : [self combineLabels:labels]];
            if (block) block(YES);
            return;
        }
        NSArray *rects = @[
            [NSValue valueWithRect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width/2, rect.size.height/2)],
            [NSValue valueWithRect:NSMakeRect(rect.origin.x + rect.size.width/2, rect.origin.y, rect.size.width/2, rect.size.height/2)],
            [NSValue valueWithRect:NSMakeRect(rect.origin.x, rect.origin.y + rect.size.height/2, rect.size.width/2, rect.size.height/2)],
            [NSValue valueWithRect:NSMakeRect(rect.origin.x + rect.size.width/2, rect.origin.y + rect.size.height/2, rect.size.width/2, rect.size.height/2)],
        ];
        if (node.count < 4) {
            YGNode *c = [[YGNode alloc] init];
            if (node.count) [c addObject:node[0]];
            node.array = @[c.mutableCopy, c.mutableCopy, c.mutableCopy, c.mutableCopy];
        }
        [self processNodesInNode:node rects:rects index:0 depth:depth + 1 same:(equal?same + 1:0) block:^(BOOL finished) {
            if (!finished) {
                if (block) block(NO);
                return;
            }
            BOOL still = [node[0] count] == 1 && [node[1] count] == 1 && [node[2] count] == 1 && [node[3] count] == 1
            && [node[0][0] isEqualToString:node[1][0]] && [node[1][0] isEqualToString:node[2][0]] && [node[2][0] isEqualToString:node[3][0]];
            if (still) {
                node.array = @[node[0][0]];
                if (block) block(YES);
                return;
            }
            if (block) block(YES);
        }];
    }];
}

- (void)processNodesInNode:(YGNode *)node rects:(NSArray *)rects index:(NSUInteger)index depth:(NSUInteger)depth same:(NSUInteger)same block:(void(^)(BOOL))block
{
    if (index < 4) {
        [self processNode:node[index] rect:[rects[index] rectValue] depth:depth same:same block:^(BOOL finished) {
            if (finished) {
                [self processNodesInNode:node rects:rects index:index + 1 depth:depth same:same block:block];
            } else {
                if (block) block(NO);
            }
        }];
    } else {
        if (block) block(YES);
    }
}

- (void)cancel
{
    _cancelled = YES;
}

+ (YGNode *)nodeAt:(NSPoint)point node:(YGNode *)node rect:(NSRect)rect
{
    if (node.count == 4) {
        NSUInteger index = 0;
        rect.size.width /= 2;
        rect.size.height /= 2;
        if (point.x >= rect.origin.x + rect.size.width) {
            index += 1;
            rect.origin.x += rect.size.width;
        }
        if (point.y >= rect.origin.y + rect.size.height) {
            index += 2;
            rect.origin.y += rect.size.height;
        }
        return [self nodeAt:point node:node[index] rect:rect];
    }
    return node;
}

@end


void dispatch_if_async(dispatch_queue_t queue, dispatch_block_t block) {
    if (block) {
        if (queue) {
            dispatch_async(queue, block);
        } else {
            block();
        }
    }
}
