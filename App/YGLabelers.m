//
//  YGLabeler.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGLabelers.h"


@implementation YGBlockLabeler

- (id)initWithRect:(NSRect)rect block:(NSString *(^)(NSPoint))block
{
    self = [super init];
    if (self) {
        _block = [block copy];
        _rect = rect;
    }
    return self;
}

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    if (block) block(_block ? _block(point) : nil);
}

@end


@implementation YGCircleLabeler

- (void)labelAtPoint:(NSPoint)p block:(void (^)(NSString *))block
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, .01 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (block) block(p.x * p.x + p.y * p.y < 1 ? @"0" : @"");
    });
}

- (NSString *)name
{
    return @"circle";
}

- (NSRect)rect
{
    return NSMakeRect(-1.5, -1.5, 3, 3);
}

@end


@implementation YGMandelbrotLabeler

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        NSPoint p = point;
        for (NSUInteger i = 0;; i++) {
            if (p.x * p.x + p.y * p.y > 4) {
                if (block) block(@"");
                break;
            }
            if (i > 100) {
                if (block) block(@"0");
                break;
            }
            float t = p.x * p.x - p.y * p.y + point.x;
            p.y = 2 * p.x * p.y + point.y;
            p.x = t;
        }
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


static float const YGPointRadius = .5f;

@implementation YGGeoJsonLabeler {
    NSArray *_tree;
    NSString *_name;
}

- (id)initWithName:(NSString *)name url:(NSURL *)url labelPath:(NSString *)labelPath
{
    self = [super init];
    if (self) {
        _name = name;
        NSData *d = [NSData dataWithContentsOfURL:url];
        NSDictionary *geojson = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSArray *triplets = [self.class tripletsWithGeoJSON:geojson labelPath:labelPath];
        _tree = [self.class treeWithTriplets:triplets rect:self.rect];
    }
    return self;
}

- (id)initWithName:(NSString *)name labelPath:(NSString *)labelPath
{
    return [self initWithName:name url:[NSBundle.mainBundle URLForResource:name withExtension:@"json"] labelPath:labelPath];
}

+ (NSRect)boxWithPoly:(NSArray *)poly radius:(float)radius
{
    float lat_min = 180, lat_max = -180, lng_min = 180, lng_max = -180;
    for (NSArray *pair in poly) {
        float lng = [pair[0] floatValue];
        float lat = [pair[1] floatValue];
        if (lng_min > lng) lng_min = lng;
        if (lng_max < lng) lng_max = lng;
        if (lat_min > lat) lat_min = lat;
        if (lat_max < lat) lat_max = lat;
    }
    return NSMakeRect(lng_min - radius, lat_min - radius, lng_max - lng_min + 2 * radius, lat_max - lat_min + 2 * radius);
}

+ (NSArray *)boxWithPoint:(NSArray *)point radius:(float)radius
{
    float lng = [point[0] floatValue];
    float lat = [point[1] floatValue];
    return @[@(lng-radius), @(lng+radius), @(lat-radius), @(lat+radius)];
}

+ (NSArray *)tripletsWithGeoJSON:(NSDictionary *)json labelPath:(NSString *)labelPath
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
            for (NSArray *poly in coordinates) {
                NSRect rect = [self boxWithPoly:poly radius:YGPointRadius];
                [result addObject:@[[NSValue valueWithRect:rect], poly, label]];
            }
        } else if ([type isEqualToString:@"MultiPolygon"]) {
            NSArray *coordinates = feature[@"geometry"][@"coordinates"];
            for (NSArray *polys in coordinates) {
                for (NSArray *poly in polys) {
                    NSRect rect = [self boxWithPoly:poly radius:YGPointRadius];
                    [result addObject:@[[NSValue valueWithRect:rect], poly, label]];
                }
            }
        } else if ([type isEqualToString:@"Point"]) {
            NSArray *coordinates = feature[@"geometry"][@"coordinates"];
            [result addObject:@[[self boxWithPoint:coordinates radius:YGPointRadius], @[coordinates], label]];
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

+ (NSArray *)treeWithTriplets:(NSArray *)triplets rect:(NSRect)rect
{
    if (triplets.count < 10) {
        return @[triplets];
    }
    NSArray *branches = @[@[].mutableCopy, @[].mutableCopy, @[].mutableCopy, @[].mutableCopy];
    NSMutableArray *rest = @[].mutableCopy;
    NSPoint mid = NSMakePoint(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height / 2);
    for (NSArray *triplet in triplets) {
        NSRect r = [triplet[0] rectValue];
        NSUInteger index = 0;
        if (r.origin.x >= mid.x) {
            index += 1;
        } else if (r.origin.x + r.size.width > mid.x) {
            [rest addObject:triplet];
            continue;
        }
        if (r.origin.y >= mid.y) {
            index += 2;
        } else if (r.origin.y + r.size.height > mid.y) {
            [rest addObject:triplet];
            continue;
        }
        [branches[index] addObject:triplet];
    }
    return @[rest,
             [self treeWithTriplets:branches[0] rect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width/2, rect.size.height/2)],
             [self treeWithTriplets:branches[1] rect:NSMakeRect(rect.origin.x + rect.size.width/2, rect.origin.y, rect.size.width/2, rect.size.height/2)],
             [self treeWithTriplets:branches[2] rect:NSMakeRect(rect.origin.x, rect.origin.y + rect.size.height/2, rect.size.width/2, rect.size.height/2)],
             [self treeWithTriplets:branches[3] rect:NSMakeRect(rect.origin.x + rect.size.width/2, rect.origin.y + rect.size.height/2, rect.size.width/2, rect.size.height/2)],
             ];
}

+ (float)distanceSqFromPoint:(NSPoint)point toPoly:(NSArray *)poly
{
    float minsq = FLT_MAX;
    if (poly.count == 1) {
        float dx = [poly[0][0] floatValue] - point.x;
        float dy = [poly[0][1] floatValue] - point.y;
        minsq = dx * dx + dy * dy;
    } else if (poly.count > 1) {
        BOOL inside = NO;
        CGPoint a = CGPointMake([poly.lastObject[0] floatValue], [poly.lastObject[1] floatValue]);
        for (NSUInteger i = 0; i < poly.count; i++) {
            CGPoint b = CGPointMake([poly[i][0] floatValue], [poly[i][1] floatValue]);
            if ((   (b.y <  point.y && a.y >= point.y)
                 || (a.y <  point.y && b.y >= point.y))
                &&  (b.x <= point.x || a.x <= point.x)) {
                inside ^= (b.x + (point.y - b.y) / (a.y - b.y) * (a.x - b.x) < point.x);
            }
            a = b;
        }
        if (inside) return 0;
        a = CGPointMake([poly.lastObject[0] floatValue], [poly.lastObject[1] floatValue]);
        for (NSUInteger i = 0; i < poly.count; i++) {
            CGPoint b = CGPointMake([poly[i][0] floatValue], [poly[i][1] floatValue]);
            CGPoint ab = CGPointMake(b.x - a.x, b.y - a.y);
            CGPoint ap = CGPointMake(point.x - a.x, point.y - a.y);
            CGFloat abap = ab.x * ap.x + ab.y * ap.y;
            CGFloat abab = ab.x * ab.x + ab.y * ab.y;
            if (abap >= 0 && abap < abab) {
                CGFloat abxap = fabsf(ab.x * ap.y - ab.y * ap.x);
                CGFloat dist = abxap * abxap / abab;
                if (minsq > dist) minsq = dist;
            }
            CGFloat apap = ap.x * ap.x + ap.y * ap.y;
            if (minsq > apap) minsq = apap;
            a = b;
        }
    }
    return minsq <= YGPointRadius * YGPointRadius ? minsq : FLT_MAX;
}

- (void)collectAt:(NSPoint)point tree:(NSArray *)tree rect:(NSRect)rect into:(NSMutableArray *)array
{
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
        [self collectAt:point tree:tree[index] rect:rect into:array];
    }
    for (NSArray *triplet in tree[0]) {
        if (NSPointInRect(point, [triplet[0] rectValue])) {
            [array addObject:triplet];
        }
    }
}

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    if (point.y >= 90 || point.y <= -90) {
        if (block) block(@"");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        float min = FLT_MAX;
        NSString *result = @"";
        NSMutableArray *triplets = @[].mutableCopy;
        [self collectAt:point tree:_tree rect:self.rect into:triplets];
        for (NSArray *triplet in triplets) {
            float d = [self.class distanceSqFromPoint:point toPoly:triplet[1]];
            if (min > d) {
                min = d;
                result = triplet[2];
                if (min == 0) break;
            }
        }
        if (block) block(result);
    });
}

- (NSString *)name
{
    return _name;
}

- (NSRect)rect
{
    return NSMakeRect(-180, -180, 360, 360);
}

@end
