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
    NSArray *_data;
    NSString *_name;
}

- (id)initWithName:(NSString *)name url:(NSURL *)url labelPath:(NSString *)labelPath
{
    self = [super init];
    if (self) {
        _name = name;
        NSData *d = [NSData dataWithContentsOfURL:url];
        NSDictionary *geojson = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        _data = [self.class flattenGeoJSON:geojson labelPath:labelPath];
    }
    return self;
}

- (id)initWithName:(NSString *)name labelPath:(NSString *)labelPath
{
    return [self initWithName:name url:[NSBundle.mainBundle URLForResource:name withExtension:@"json"] labelPath:labelPath];
}

+ (NSArray *)boxWithPoly:(NSArray *)poly radius:(float)radius
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
    return @[@(lng_min-radius), @(lng_max+radius), @(lat_min-radius), @(lat_max+radius)];
}

+ (NSArray *)boxWithPoint:(NSArray *)point radius:(float)radius
{
    float lng = [point[0] floatValue];
    float lat = [point[1] floatValue];
    return @[@(lng-radius), @(lng+radius), @(lat-radius), @(lat+radius)];
}

+ (NSArray *)flattenGeoJSON:(NSDictionary *)json labelPath:(NSString *)labelPath
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
                [result addObject:@[[self boxWithPoly:poly radius:YGPointRadius], poly, label]];
            }
        } else if ([type isEqualToString:@"MultiPolygon"]) {
            NSArray *coordinates = feature[@"geometry"][@"coordinates"];
            for (NSArray *polys in coordinates) {
                for (NSArray *poly in polys) {
                    [result addObject:@[[self boxWithPoly:poly radius:YGPointRadius], poly, label]];
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

+ (float)distanceSqFromPoint:(NSPoint)point toPoly:(NSArray *)poly inBox:(NSArray *)box
{
    if (point.x < [box[0] floatValue] || point.x > [box[1] floatValue] || point.y < [box[2] floatValue] || point.y > [box[3] floatValue]) {
        return FLT_MAX;
    }
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

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    if (point.y >= 90 || point.y <= -90) {
        if (block) block(@"");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        float min = FLT_MAX;
        NSString *result = @"";
        for (NSArray *triplet in _data) {
            float d = [self.class distanceSqFromPoint:point toPoly:triplet[1] inBox:triplet[0]];
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
