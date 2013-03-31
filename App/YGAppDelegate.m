//
//  YGAppDelegate.m
//  Yggdrasil
//
//  Copyright (c) 2013 leo. All rights reserved.
//

#import "YGAppDelegate.h"
#import "YGController.h"
#import "YGLabelers.h"


@implementation YGAppDelegate {
    IBOutlet YGController *controller;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSArray *labelers = @[
        [[YGCircleLabeler alloc] init],
        [[YGMandelbrotLabeler alloc] init],
        [[YGGeoJsonLabeler alloc] initWithName:@"countries" labelPath:@"properties.name"],
        [[YGGeoJsonLabeler alloc] initWithName:@"cities" labelPath:@"properties.name"],
    ];
    [controller setupWithLabelers:labelers min:4 max:8 sub:2];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [controller stop]; controller = nil;
}

@end
