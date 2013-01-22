//
//  YGController.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGController.h"
#import "YGLabelers.h"


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
@end
@implementation YGRun
@end


@implementation YGController {
    IBOutlet YGView *_drawView;
    IBOutlet NSButton *_runButton;
    IBOutlet NSProgressIndicator *_progressBar;
    IBOutlet NSTextField *_infoLabel;
    IBOutlet NSStepper *_minStepper;
    IBOutlet NSStepper *_maxStepper;
    IBOutlet NSStepper *_subStepper;
    IBOutlet NSTextField *_minLabel;
    IBOutlet NSTextField *_maxLabel;
    IBOutlet NSTextField *_subLabel;
    IBOutlet NSComboBox *_labelerCombo;
    NSArray *_labelers;
    YGRun *_run;
}


#pragma mark - Object life cycle

- (void)setupWithLabelers:(NSArray *)labelers min:(NSUInteger)min max:(NSUInteger)max sub:(NSUInteger)sub
{
    _labelers = labelers;
    _minStepper.intValue = min;
    _maxStepper.intValue = max;
    _subStepper.intValue = sub;
    [_labelerCombo removeAllItems];
    for (id<YGLabeler> labeler in labelers) {
        [_labelerCombo addItemWithObjectValue:labeler.name];
    }
    [_labelerCombo selectItemAtIndex:0];
    [self step:nil];
    [self select:nil];
}

+ (void)saveNode:(YGNode *)node name:(NSString *)name
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:node options:0 error:nil];
    if (data.length) {
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        string = [string stringByReplacingOccurrencesOfString:@"],[" withString:@"]["];
        string = [string stringByReplacingOccurrencesOfString:@"," withString:@"_"];
        string = [string stringByReplacingOccurrencesOfString:@"][" withString:@"],["];
        string = [string stringByReplacingOccurrencesOfString:@"[\"" withString:@""];
        string = [string stringByReplacingOccurrencesOfString:@"\"]" withString:@""];
        string = [string stringByReplacingOccurrencesOfString:@"[]" withString:@""];
        NSString *path = [[YGScanner tempDir] stringByAppendingPathComponent:[name stringByAppendingString:@".ygg"]];
        [string writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
}

+ (YGNode *)loadName:(NSString *)name
{
    YGNode *result = [[YGNode alloc] init];
    if (name.length) {
        NSString *path = [[YGScanner tempDir] stringByAppendingPathComponent:[name stringByAppendingString:@".ygg"]];
        NSString *string = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (string.length) {
            string = [string stringByReplacingOccurrencesOfString:@"([^,\\[\\]]+)" withString:@"[\"$1\"]" options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
            string = [string stringByReplacingOccurrencesOfString:@"[," withString:@"[[\"\"],"];
            string = [string stringByReplacingOccurrencesOfString:@",," withString:@",[\"\"],"];
            string = [string stringByReplacingOccurrencesOfString:@",," withString:@",[\"\"],"];
            string = [string stringByReplacingOccurrencesOfString:@",]" withString:@",[\"\"]]"];
            result = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
        }
    }
    return result;
}


#pragma mark - Actions

- (IBAction)run:(id)sender {
    if (!_run.scanner.running) {
        [_runButton setTitle:@"Stop"];
        [_run.scanner cancel];
        
        _run = [[YGRun alloc] init];
        _run.labeler = _labelers[_labelerCombo.indexOfSelectedItem];
        _run.node = [[YGNode alloc] init];
        _run.node.array = _drawView.node;
        _run.scanner = [[YGScanner alloc] initWithLabeler:_run.labeler minDepth:_minStepper.intValue maxDepth:_maxStepper.intValue subSample:_subStepper.intValue];
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
        _infoLabel.stringValue = @"cancelled";
        [_run.scanner cancel];
    }
}

- (IBAction)step:(id)sender
{
    _minLabel.stringValue = [NSString stringWithFormat:@"min:%u", _minStepper.intValue];
    _maxLabel.stringValue = [NSString stringWithFormat:@"max:%u", _maxStepper.intValue];
    _subLabel.stringValue = [NSString stringWithFormat:@"sub:%u", _subStepper.intValue];
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

#pragma mark - Scanner callback

- (void)scannerAtRect:(NSRect)rect depth:(NSUInteger)depth
{
    if (_run) {
        _run.progress += 1.0 / (1 << depth * 2);
        if (_run.progress < 0) _run.progress = 0;
        if (_run.progress > 1) _run.progress = 1;
        if (!_run.lastDraw || -[_run.lastDraw timeIntervalSinceNow] > MIN(1, MAX(.2, _drawView.lastTime * 20))) {
            _progressBar.doubleValue = _run.progress;
            _drawView.lastRect = rect;
            [_drawView setNeedsDisplay:YES];
            _run.lastDraw = NSDate.date;
        }
        if (!_run.lastUpdate || -[_run.lastUpdate timeIntervalSinceNow] > 10) {
            NSTimeInterval timeSpan = -[_run.lastUpdate timeIntervalSinceNow];
            double progressSpan = _run.progress - _run.lastProgress;
            NSTimeInterval estimate = (1 - _run.progress) / progressSpan * timeSpan;
            if (progressSpan <= 0 || estimate <= 0) {
                _infoLabel.stringValue = [NSString stringWithFormat:@".."];
            } else if (estimate > 3600 * 1.5) {
                _infoLabel.stringValue = [NSString stringWithFormat:@"%.0f hours", estimate / 3600];
            } else if (estimate > 60 * 1.5) {
                _infoLabel.stringValue = [NSString stringWithFormat:@"%.0f minutes", estimate / 60];
            } else {
                _infoLabel.stringValue = [NSString stringWithFormat:@"%.0f seconds", estimate];
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
            if (r.size.width < 1) {
                r.origin.x -= (1 - r.size.width) / 2;
                r.size.width = 1;
            }
            if (r.size.height < 1) {
                r.origin.y -= (1 - r.size.height) / 2;
                r.size.height = 1;
            }
            if (r.size.width < 1) r.size.width = 1;
            if (r.size.height < 1) r.size.height = 1;
            [[NSColor colorWithDeviceWhite:1 alpha:1] set];
            NSRectFill(r);
        }
    }
}

- (void)drawNode:(YGNode *)node rect:(NSRect)rect
{
    if (node.count == 1) {
        [[self.class colorWithLabel:node[0]] set];
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
