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
                          [[YGGeoJsonLabeler alloc] initWithName:@"countries" labelPath:@"properties.name"],
                          [[YGGeoJsonLabeler alloc] initWithName:@"cities" labelPath:@"properties.name"],
                          [[YGMandelbrotLabeler alloc] init],
                          [[YGCircleLabeler alloc] init],
                          ];
    [controller setupWithLabelers:labelers depth:8];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [controller stop]; controller = nil;
}

@end
