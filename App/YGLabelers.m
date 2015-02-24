//
//  YGLabeler.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGLabelers.h"


@implementation YGBlockLabeler

- (id)initWithName:(NSString *)name rect:(NSRect)rect async:(BOOL)async block:(NSString *(^)(NSPoint))block
{
    self = [super init];
    if (self) {
        _block = [block copy];
        _name = name;
        _rect = rect;
        _async = async;
    }
    return self;
}

- (NSString *)labelAtPoint:(NSPoint)point
{
    return _block ? _block(point) : nil;
}

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    if (_async) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            if (block) block([self labelAtPoint:point]);
        });
    } else {
       if (block) block([self labelAtPoint:point]);
    }
}

@end


@implementation YGCircleLabeler

- (instancetype)init
{
    return [self initWithName:@"circle" rect:NSMakeRect(-1.5, -1.5, 3, 3) async:YES block:^NSString *(NSPoint point) {
        return point.x * point.x + point.y * point.y < 1 ? @"0" : @"";
    }];
}

@end


@implementation YGMandelbrotLabeler

- (NSString *)labelAtPoint:(NSPoint)point
{
    NSPoint p = point;
    for (NSUInteger i = 0;; i++) {
        if (p.x * p.x + p.y * p.y > 4) {
            return [NSString stringWithFormat:@"%c%c", 'a' + ((char)i & 0x0F), 'a' + ((char)(i >> 4) & 0x0F)];
        }
        if (i > 255) {
            return @"";
        }
        float t = p.x * p.x - p.y * p.y + point.x;
        p.y = 2 * p.x * p.y + point.y;
        p.x = t;
    }
}

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        if (block) block([self labelAtPoint:point]);
    });
}

- (NSString *)name
{
    return @"mandelbrot";
}

- (NSRect)rect
{
    return NSMakeRect(-2, -2, 4, 4);
}

@end


@implementation YGGeoJsonLabeler {
    NSArray *_tree;
    NSString *_name;
}

- (id)initWithName:(NSString *)name url:(NSURL *)url labelPath:(NSString *)labelPath radius:(float)radius
{
    self = [super init];
    if (self) {
        _name = name;
        NSData *d = [NSData dataWithContentsOfURL:url];
        NSDictionary *geojson = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSArray *leafs = [self.class leafsWithGeoJSON:geojson labelPath:labelPath defaultRadius:radius];
        _tree = [self.class treeWithLeafs:leafs rect:self.rect];
    }
    return self;
}

- (id)initWithName:(NSString *)name labelPath:(NSString *)labelPath
{
    return [self initWithName:name url:[NSBundle.mainBundle URLForResource:name withExtension:@"json"] labelPath:labelPath radius:0.4f];
}

- (NSString *)name
{
    return _name;
}

- (NSRect)rect
{
    return NSMakeRect(-180, -180, 360, 360);
}


#pragma mark - Loading GeoJSON

+ (NSArray *)leafWithPairs:(NSArray *)pairs radius:(float)radius label:(NSString *)label
{
    NSMutableArray *poly = @[].mutableCopy;
    float lat_min = 180, lat_max = -180, lng_min = 180, lng_max = -180;
    for (NSArray *pair in pairs) {
        NSPoint point = NSMakePoint([pair[0] floatValue], [pair[1] floatValue]);
        [poly addObject:[NSValue valueWithPoint:point]];
        if (lng_min > point.x) lng_min = point.x;
        if (lng_max < point.x) lng_max = point.x;
        if (lat_min > point.y) lat_min = point.y;
        if (lat_max < point.y) lat_max = point.y;
    }
    NSRect box = NSMakeRect(lng_min - radius, lat_min - radius, lng_max - lng_min + 2 * radius, lat_max - lat_min + 2 * radius);
    return @[[NSValue valueWithRect:box], poly, @(radius), label];
}

+ (NSArray *)leafsWithGeoJSON:(NSDictionary *)json labelPath:(NSString *)labelPath defaultRadius:(float)defaultRadius
{
    NSMutableArray *result = @[].mutableCopy;
    NSArray *features = json[@"features"];
    NSArray *labelKeys = [labelPath componentsSeparatedByString:@"."];
    for (NSDictionary *feature in features) {
        id label = feature;
        for (NSString *key in labelKeys) {
            label = label[key];
        }
        if (![label isKindOfClass:NSString.class]) {
            NSLog(@"No string found a label path: %@", [labelKeys componentsJoinedByString:@" . "]);
            return nil;
        }
        NSString *type = feature[@"geometry"][@"type"];
        if ([type isEqualToString:@"Polygon"]) {
            NSArray *coordinates = feature[@"geometry"][@"coordinates"];
            float radius = feature[@"geometry"][@"radius"] ? [feature[@"geometry"][@"radius"] floatValue] : defaultRadius;
            for (NSArray *pairs in coordinates) {
                [result addObject:[self leafWithPairs:pairs radius:radius label:label]];
            }
        } else if ([type isEqualToString:@"MultiPolygon"]) {
            NSArray *coordinates = feature[@"geometry"][@"coordinates"];
            float radius = feature[@"geometry"][@"radius"] ? [feature[@"geometry"][@"radius"] floatValue] : defaultRadius;
            for (NSArray *polys in coordinates) {
                for (NSArray *pairs in polys) {
                    [result addObject:[self leafWithPairs:pairs radius:radius label:label]];
                }
            }
        } else if ([type isEqualToString:@"Point"]) {
            NSArray *pairs = @[feature[@"geometry"][@"coordinates"]];
            float radius = feature[@"geometry"][@"radius"] ? [feature[@"geometry"][@"radius"] floatValue] : defaultRadius;
            [result addObject:[self leafWithPairs:pairs radius:radius label:label]];
        } else {
            NSLog(@"Unknown geometry type: %@", type);
            return nil;
        }
    }
    if (!result.count) {
        NSLog(@"No polygons were found in GeoJSON data");
        return nil;
    }
    return result;
}

+ (NSArray *)treeWithLeafs:(NSArray *)leafs rect:(NSRect)rect
{
    if (leafs.count < 4) {
        return @[leafs];
    }
    NSArray *branches = @[@[].mutableCopy, @[].mutableCopy, @[].mutableCopy, @[].mutableCopy];
    NSMutableArray *node = @[].mutableCopy;
    rect.size.width /= 2;
    rect.size.height /= 2;
    NSPoint mid = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
    for (NSArray *leaf in leafs) {
        NSRect r = [leaf[0] rectValue];
        NSUInteger index = 0;
        if (r.origin.x >= mid.x) {
            index += 1;
        } else if (r.origin.x + r.size.width > mid.x) {
            [node addObject:leaf];
            continue;
        }
        if (r.origin.y >= mid.y) {
            index += 2;
        } else if (r.origin.y + r.size.height > mid.y) {
            [node addObject:leaf];
            continue;
        }
        [branches[index] addObject:leaf];
    }
    NSMutableArray *result = @[node].mutableCopy;
    for (NSUInteger i = 0; i < 4; i++) {
        NSRect r = NSMakeRect(rect.origin.x + (i % 2) * rect.size.width, rect.origin.y + (i / 2) * rect.size.height, rect.size.width, rect.size.height);
        [result addObject:[self treeWithLeafs:branches[i] rect:r]];
    }
    return result;
}


#pragma mark - Label lookup

+ (float)distanceSqFromPoint:(NSPoint)point toPoly:(NSArray *)poly
{
    if (poly.count == 1) {
        NSPoint p = [poly[0] pointValue];
        float dx = p.x - point.x;
        float dy = p.y - point.y;
        return dx * dx + dy * dy;
    } {
        BOOL inside = NO;
        NSPoint a = [poly.lastObject pointValue];
        for (NSUInteger i = 0; i < poly.count; i++) {
            NSPoint b = [poly[i] pointValue];
            if (((b.y < point.y && a.y >= point.y) || (a.y < point.y && b.y >= point.y)) && (b.x <= point.x || a.x <= point.x)) {
                inside ^= (b.x + (point.y - b.y) / (a.y - b.y) * (a.x - b.x) < point.x);
            }
            a = b;
        }
        if (inside) return 0;
    } {
        float result = FLT_MAX;
        NSPoint a = [poly.lastObject pointValue];
        for (NSUInteger i = 0; i < poly.count; i++) {
            NSPoint b = [poly[i] pointValue];
            NSPoint ab = NSMakePoint(b.x - a.x, b.y - a.y);
            NSPoint ap = NSMakePoint(point.x - a.x, point.y - a.y);
            float abap = ab.x * ap.x + ab.y * ap.y;
            float abab = ab.x * ab.x + ab.y * ab.y;
            if (abap >= 0 && abap < abab) {
                float abxap = fabsf(ab.x * ap.y - ab.y * ap.x);
                float dist = abxap * abxap / abab;
                if (result > dist) result = dist;
            }
            float apap = ap.x * ap.x + ap.y * ap.y;
            if (result > apap) result = apap;
            a = b;
        }
        return result;
    }
}

- (NSString *)labelAtPoint:(NSPoint)point tree:(NSArray *)tree rect:(NSRect)rect min:(float *)min
{
    NSString *result = @"";
    if (tree.count > 1) {
        NSUInteger index = 1;
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
        result = [self labelAtPoint:point tree:tree[index] rect:rect min:min];
        if (*min == 0) return result;
    }
    for (NSArray *leaf in tree[0]) {
        if (NSPointInRect(point, [leaf[0] rectValue])) {
            float distSq = [self.class distanceSqFromPoint:point toPoly:leaf[1]];
            float radius = [leaf[2] floatValue];
            if (*min > distSq && radius * radius >= distSq) {
                *min = distSq;
                result = leaf[3];
                if (*min == 0) return result;
            }
        }
    }
    return result;
}

- (NSString *)labelAtPoint:(NSPoint)point
{
    float min = FLT_MAX;
    return [self labelAtPoint:point tree:_tree rect:self.rect min:&min];
}

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (block) block([self labelAtPoint:point]);
    });
}

@end
