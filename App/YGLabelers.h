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
@property (nonatomic, assign) BOOL async;

- (id)initWithName:(NSString *)name rect:(NSRect)rect async:(BOOL)async block:(NSString *(^)(NSPoint))block;

@end


@interface YGCircleLabeler : YGBlockLabeler
@end


@interface YGMandelbrotLabeler : NSObject <YGLabeler>
@end


@interface YGGeoJsonLabeler : NSObject <YGLabeler>
- (id)initWithName:(NSString *)name labelPath:(NSString *)labelPath;
- (id)initWithName:(NSString *)name url:(NSURL *)url labelPath:(NSString *)labelPath radius:(float)radius;
@end
