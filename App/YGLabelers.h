//
//  YGLabelers.h
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGScanner.h"


@interface YGBlockLabeler : NSObject <YGLabeler>

@property (nonatomic, copy) NSString *(^block)(NSPoint);
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSRect rect;

- (id)initWithRect:(NSRect)rect block:(NSString *(^)(NSPoint))block;

@end


@interface YGCircleLabeler : NSObject <YGLabeler>
@end


@interface YGMandelbrotLabeler : NSObject <YGLabeler>
@end


@interface YGGeoJsonLabeler : NSObject <YGLabeler>
- (id)initWithName:(NSString *)name labelPath:(NSString *)labelPath;
- (id)initWithName:(NSString *)name url:(NSURL *)url labelPath:(NSString *)labelPath radius:(float)radius;
@end
