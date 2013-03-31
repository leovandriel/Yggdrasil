//
//  YGController.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGController.h"
#import "YGLabelers.h"
#import "YGFormat.h"


@interface YGView : NSView
@property (nonatomic, strong) YGNode *node;
@property (nonatomic, assign) NSRect rect;
@property (nonatomic, assign) NSRect lastRect;
@property (nonatomic, assign) NSTimeInterval lastTime;
@property (nonatomic, strong) NSArray *path;
@end


@interface YGRun : NSObject
@property (nonatomic, strong) id<YGLabeler> labeler;
@property (nonatomic, strong) YGNode *node;
@property (nonatomic, strong) YGScanner *scanner;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) double lastProgress;
@property (nonatomic, strong) NSDate *lastUpdate;
@property (nonatomic, strong) NSDate *lastDraw;
@property (nonatomic, assign) NSTimeInterval lastEstimate;
@end
@implementation YGRun
@end


@implementation YGController {
    IBOutlet YGView *_drawView;
    IBOutlet NSButton *_runButton;
    IBOutlet NSProgressIndicator *_progressBar;
    IBOutlet NSTextField *_infoLabel;
    IBOutlet NSStepper *_depthStepper;
    IBOutlet NSTextField *_depthLabel;
    IBOutlet NSComboBox *_labelerCombo;
    IBOutlet NSPopUpButton *_exportButton;
    NSArray *_labelers;
    YGRun *_run;
}


#pragma mark - Object life cycle

- (void)setupWithLabelers:(NSArray *)labelers depth:(NSUInteger)depth
{
    _labelers = labelers;
    _depthStepper.intValue = depth;
    [_labelerCombo removeAllItems];
    for (id<YGLabeler> labeler in labelers) {
        [_labelerCombo addItemWithObjectValue:labeler.name];
    }
    [_labelerCombo selectItemAtIndex:0];
    [self step:nil];
    [self select:nil];
}


#pragma mark - Tree serialization

+ (NSString *)nodePathWithName:(NSString *)name
{
    return [[YGScanner tempDir] stringByAppendingPathComponent:[name stringByAppendingString:@".ygg"]];
}

+ (void)saveNode:(YGNode *)node name:(NSString *)name
{
    if (node && name.length) {
        NSData *data = [YGFormat dataWithNode:node];
        NSString *path = [self nodePathWithName:name];
        [data writeToFile:path atomically:NO];
    }
}

+ (YGNode *)loadName:(NSString *)name
{
    if (name.length) {
        NSString *path = [self nodePathWithName:name];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) return [YGFormat nodeWithData:data];
    }
    return nil;
}

+ (void)clearNodeWithName:(NSString *)name
{
    if (name.length) {
        NSString *path = [self.class nodePathWithName:name];
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}


#pragma mark - Actions

- (IBAction)run:(id)sender {
    if (!_run.scanner.running) {
        [_runButton setTitle:@"Stop"];
        _exportButton.enabled = NO;
        [_run.scanner cancel];
        
        _run = [[YGRun alloc] init];
        _run.labeler = _labelers[_labelerCombo.indexOfSelectedItem];
        _run.node = [[YGNode alloc] init];
        _run.node.array = _drawView.node;
        NSUInteger max = _depthStepper.integerValue, min = MAX(max, 2) - 2, sub = 2;
        _run.scanner = [[YGScanner alloc] initWithLabeler:_run.labeler minDepth:min maxDepth:max subSample:sub];
        _run.scanner.delegate = self;

        _progressBar.doubleValue = 0;
        _infoLabel.stringValue = @"..";
        _drawView.node = _run.node;
        _drawView.rect = _run.labeler.rect;
        _drawView.lastTime = 0;
        _drawView.lastRect = NSZeroRect;
        _drawView.path = nil;
        
        [_run.scanner processNode:_run.node block:^(BOOL finished) {
            [_runButton setTitle:@"Start"];
            _exportButton.enabled = YES;
            if (finished) {
                _infoLabel.stringValue = @"finished";
                _progressBar.doubleValue = 1;
                [self.class saveNode:_run.node name:_run.labeler.name];
            } else if (_run) {
                _infoLabel.stringValue = @"cancelled";
            }
            _drawView.lastRect = NSZeroRect;
            [_drawView setNeedsDisplay:YES];
        }];
    } else {
        [_runButton setTitle:@"Start"];
        _exportButton.enabled = YES;
        _infoLabel.stringValue = @"cancelled";
        [_run.scanner cancel];
    }
}

- (IBAction)step:(id)sender
{
    _depthLabel.stringValue = [NSString stringWithFormat:@"depth:%u", _depthStepper.intValue];
}

- (IBAction)select:(id)sender
{
    [_run.scanner cancel];
    _run = nil;
    id<YGLabeler> labeler = _labelers[_labelerCombo.indexOfSelectedItem];
    _drawView.node = [self.class loadName:labeler.name];
    _drawView.rect = labeler.rect;
    _drawView.lastRect = NSZeroRect;
    _drawView.path = nil;
    _progressBar.doubleValue = 0;
    _infoLabel.stringValue = @"";
    [_drawView setNeedsDisplay:YES];
}

- (void)stop
{
    [_run.scanner cancel];
    _run = nil;
}

- (IBAction)clear:(id)sender
{
    if (_labelerCombo.stringValue) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"When you clear this label, all label data and cache will be deleted." defaultButton:@"Cancel" alternateButton:@"Clear Label" otherButton:nil informativeTextWithFormat:@"This is generally desired if the underlying labeler changed and you want to get rid of all cached labels."];
        if ([alert runModal] == NSAlertAlternateReturn) {
            [_run.scanner cancel];
            [_run.scanner clearCache];
            [YGScanner clearCacheWithName:_labelerCombo.stringValue];
            [self.class clearNodeWithName:_labelerCombo.stringValue];
            [self select:nil];
        }
    }
}
   
- (IBAction)export:(id)sender
{
    NSUInteger format = _exportButton.indexOfSelectedItem;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = [NSString stringWithFormat:@"%@.ygg", _labelerCombo.stringValue];
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton && panel.URL) {
            NSData *data = nil;
            switch (format) {
                case 1: data = [YGFormat plainDataWithNode:_drawView.node]; break;
                case 2: data = [YGFormat textDataWithNode:_drawView.node]; break;
                case 3: data = [YGFormat binaryDataWithNode:_drawView.node]; break;
                case 4: data = [YGFormat sourceDataWithNode:_drawView.node]; break;
            }
            [data writeToURL:panel.URL atomically:YES];
        }
        [_exportButton selectItemAtIndex:0];
    }];
}

#pragma mark - Scanner callback

- (void)scannerAtRect:(NSRect)rect depth:(NSUInteger)depth
{
    if (_run) {
        _run.progress += 1.0 / (1 << depth * 2);
        if (_run.progress < 0) _run.progress = 0;
        if (_run.progress > 1) _run.progress = 1;
        if (!_run.lastDraw || -[_run.lastDraw timeIntervalSinceNow] > MIN(2, MAX(.2, _drawView.lastTime * 20))) {
            _progressBar.doubleValue = _run.progress;
            _drawView.lastRect = rect;
            [_drawView setNeedsDisplay:YES];
            _run.lastDraw = NSDate.date;
        }
        if (!_run.lastUpdate || -[_run.lastUpdate timeIntervalSinceNow] > 3) {
            NSTimeInterval timeSpan = -[_run.lastUpdate timeIntervalSinceNow];
            double progressSpan = _run.progress - _run.lastProgress;
            NSTimeInterval estimate = (1 - _run.progress) / progressSpan * timeSpan;
            if (estimate > 0) {
                if (_run.lastEstimate > 10) {
                    estimate = .1 * (estimate - _run.lastEstimate) + _run.lastEstimate;
                }
                _run.lastEstimate = estimate;
                if (estimate > 3600 * 1.5) {
                    _infoLabel.stringValue = [NSString stringWithFormat:@"%.0f hours", estimate / 3600];
                } else if (estimate > 60 * 1.5) {
                    _infoLabel.stringValue = [NSString stringWithFormat:@"%.0f minutes", estimate / 60];
                } else {
                    _infoLabel.stringValue = [NSString stringWithFormat:@"%.0f seconds", estimate];
                }
            } else {
                _infoLabel.stringValue = [NSString stringWithFormat:@".."];
            }
            _run.lastProgress = _run.progress;
            _run.lastUpdate = NSDate.date;
        }
    }
}

@end


@implementation YGView

+ (NSColor *)colorWithLabel:(NSString *)label
{
    if (label.length) {
        NSUInteger c = 0;
        for (NSUInteger i = 0; i < label.length; i++) {
            c = 7 * c + 23 * [label characterAtIndex:i];
        }
        return [NSColor colorWithDeviceHue:(c % 32) / 32.f saturation:1 brightness:.5 alpha:1];
    }
    return [NSColor colorWithDeviceWhite:.4 alpha:1];
}

- (NSRect)drawRect
{
    NSRect result = self.bounds;
    if (result.size.width > result.size.height) {
        result.origin.x += (result.size.width - result.size.height) / 2;
        result.size.width = result.size.height;
    } else if (result.size.height > result.size.width) {
        result.origin.y += (result.size.height - result.size.width) / 2;
        result.size.height = result.size.width;
    }
    return result;
}

- (void)drawRect:(NSRect)_
{
    NSRect drawRect = [self drawRect];
    [[NSColor colorWithDeviceWhite:.6 alpha:1] set];
    NSRectFill(_path.count ? self.bounds : drawRect);
    if (_node) {
        YGNode *node = _node;
        NSRect rect = _rect;
        for (NSNumber *number in _path) {
            NSUInteger index = number.unsignedIntegerValue;
            if ([node isKindOfClass:[YGNode class]] && index < node.count) {
                node = node[index];
                rect.size.width /= 2;
                rect.size.height /= 2;
                if (index % 2) rect.origin.x += rect.size.width;
                if (index / 2) rect.origin.y += rect.size.height;
            } else {
                break;
            }
        }
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self drawNode:node rect:drawRect];
        _lastTime = CFAbsoluteTimeGetCurrent() - start;
        if (!NSIsEmptyRect(_lastRect)) {
            NSRect r = NSMakeRect((_lastRect.origin.x - rect.origin.x) * drawRect.size.width / rect.size.width + drawRect.origin.x, (_lastRect.origin.y - rect.origin.y) * drawRect.size.height / rect.size.height + drawRect.origin.y, _lastRect.size.width * drawRect.size.width / rect.size.width, _lastRect.size.height * drawRect.size.height / rect.size.height);
            if (r.size.width < 2) {
                r.origin.x -= (2 - r.size.width) / 2;
                r.size.width = 2;
            }
            if (r.size.height < 2) {
                r.origin.y -= (2 - r.size.height) / 2;
                r.size.height = 2;
            }
            [[NSColor colorWithDeviceWhite:1 alpha:1] set];
            NSRectFill(r);
        }
    }
}

- (void)drawNode:(YGNode *)node rect:(NSRect)rect
{
    if (node.count == 1 || rect.size.width * rect.size.height < 9) {
        for (BOOL first = YES; node.count == 4; first = NO) node = node[first ? 3 : 0];
        [[self.class colorWithLabel:node.count ? node[0] : nil] set];
        NSRectFill(NSInsetRect(rect, .1, .1));
    } else if (node.count == 4) {
        rect.size.width /= 2;
        rect.size.height /= 2;
        [self drawNode:node[0] rect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
        [self drawNode:node[1] rect:NSMakeRect(rect.origin.x + rect.size.width, rect.origin.y, rect.size.width, rect.size.height)];
        [self drawNode:node[2] rect:NSMakeRect(rect.origin.x, rect.origin.y + rect.size.height, rect.size.width, rect.size.height)];
        [self drawNode:node[3] rect:NSMakeRect(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height, rect.size.width, rect.size.height)];
    }
}

- (void)mouseUp:(NSEvent *)event {
    NSRect rect = [self drawRect];
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger index = 4;
    for (NSUInteger i = 0; i < 4; i++) {
        if (NSPointInRect(point, NSMakeRect(rect.origin.x + (i%2) * rect.size.width/2, rect.origin.y + (i/2) * rect.size.height/2, rect.size.width/2, rect.size.height/2))) {
            index = i;
            break;
        }
    }
    if (index < 4) {
        if (!_path) _path = @[];
        _path = [_path arrayByAddingObject:@(index)];
    } else if (_path.count) {
        _path = [_path subarrayWithRange:NSMakeRange(0, _path.count - 1)];
    }
    [self setNeedsDisplay:YES];
}

@end
