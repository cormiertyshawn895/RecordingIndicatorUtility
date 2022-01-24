//
//  AppKitRedeclaration.h
//  Recording Indicator Utility
//

#import <QuartzCore/CALayer.h>

NS_ASSUME_NONNULL_BEGIN

// WindowServer cannot link AppKit. Redeclare a few interfaces for Control Center.
@interface NSView : NSObject
@property BOOL wantsLayer;
@property (nullable, strong) CALayer *layer;
@end

@interface NSColor : NSObject
+ (NSColor *)colorWithSRGBRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
@property (readonly) CGColorRef CGColor;
@end

@interface NSPrivacyIndicatorView : NSObject
- (instancetype)initWithFrame:(NSRect)frameRect;
@end

@interface NSWindow : NSObject
@property (copy) NSString *title;
@property (nullable, strong) NSView *contentView;
@end

@interface NSPanel : NSWindow
@end

NS_ASSUME_NONNULL_END
