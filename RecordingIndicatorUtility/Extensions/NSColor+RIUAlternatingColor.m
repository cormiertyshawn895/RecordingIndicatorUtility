//
//  NSColor+RIUAlternatingColor.m
//  Recording Indicator Utility
//

#import "NSColor+RIUAlternatingColor.h"

@implementation NSColor (RIUAlternatingColor)

+ (NSArray<NSColor *> *)controlAlternatingRowBackgroundColors {
    return @[ NSColor.clearColor, [NSColor colorNamed:@"AlternateRowBackground"] ];
}

+ (NSArray<NSColor *> *)alternatingContentBackgroundColors {
    return @[ NSColor.clearColor, [NSColor colorNamed:@"AlternateRowBackground"] ];
}

@end
