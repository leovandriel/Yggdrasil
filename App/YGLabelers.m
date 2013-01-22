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

+ (NSArray *)boxWithPoly:(NSArray *)poly
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
    return @[@(lng_min), @(lng_max), @(lat_min), @(lat_max)];
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
                [result addObject:@[[self boxWithPoly:poly], poly, label]];
            }
        } else if ([type isEqualToString:@"MultiPolygon"]) {
            NSArray *coordinates = feature[@"geometry"][@"coordinates"];
            for (NSArray *polys in coordinates) {
                for (NSArray *poly in polys) {
                    [result addObject:@[[self boxWithPoly:poly], poly, label]];
                }
            }
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

+ (BOOL)point:(NSPoint)point inPoly:(NSArray *)poly inBox:(NSArray *)box
{
    if (point.x < [box[0] floatValue] || point.x > [box[1] floatValue] || point.y < [box[2] floatValue] || point.y > [box[3] floatValue]) {
        return NO;
    }
    BOOL result = NO;
    for (NSUInteger i = 0, j = poly.count - 1; i < poly.count; i++) {
        if ((   ([poly[i][1] floatValue] <  point.y && [poly[j][1] floatValue] >= point.y)
             || ([poly[j][1] floatValue] <  point.y && [poly[i][1] floatValue] >= point.y))
            &&  ([poly[i][0] floatValue] <= point.x || [poly[j][0] floatValue] <= point.x)) {
            result ^= ([poly[i][0] floatValue] + (point.y - [poly[i][1] floatValue]) / ([poly[j][1] floatValue] - [poly[i][1] floatValue]) * ([poly[j][0] floatValue] - [poly[i][0] floatValue]) < point.x);
        }
        j = i;
    }
    
    return result;
}

- (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block
{
    if (point.y >= 90 || point.y <= -90) {
        if (block) block(@"");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSArray *triplet in _data) {
            if ([self.class point:point inPoly:triplet[1] inBox:triplet[0]]) {
                if (block) block(triplet[2]);
                return;
            }
        }
        if (block) block(@"");
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
