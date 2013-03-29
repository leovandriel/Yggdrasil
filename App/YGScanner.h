//
//  YGScanner.h
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

typedef NSMutableArray YGNode;
@protocol YGLabeler, YGProgressDelegate;


@interface YGScanner : NSObject

@property (nonatomic, assign) NSUInteger maxDepth;
@property (nonatomic, assign) NSUInteger minDepth;
@property (nonatomic, assign) NSUInteger subSample;
@property (nonatomic, strong) id<YGLabeler> labeler;

@property (nonatomic, readonly) BOOL running;
@property (nonatomic, weak) id<YGProgressDelegate> delegate;
@property (nonatomic, assign) BOOL useCaching;
@property (nonatomic, strong) dispatch_queue_t queue;

- (id)initWithLabeler:(id<YGLabeler>)labeler minDepth:(NSUInteger)minDepth maxDepth:(NSUInteger)maxDepth subSample:(NSUInteger)subSample;

- (void)processNode:(YGNode *)node block:(void(^)(BOOL))block;
- (void)cancel;

- (void)clearCache;
+ (void)clearCacheWithName:(NSString *)name;
+ (YGNode *)nodeAt:(NSPoint)point node:(YGNode *)node rect:(NSRect)rect;
+ (NSString *)tempDir;

@end


@protocol YGProgressDelegate <NSObject>
- (void)scannerAtRect:(NSRect)rect depth:(NSUInteger)depth;
@end


@protocol YGLabeler <NSObject>
- (NSString *)name;
- (NSRect)rect;
- (void)labelAtPoint:(NSPoint)point block:(void(^)(NSString *))block;
@end
