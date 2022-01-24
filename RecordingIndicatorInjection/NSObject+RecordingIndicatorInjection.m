//
//  NSObject+RecordingIndicatorInjection.m
//  RecordingIndicatorInjection
//

#import "NSObject+RecordingIndicatorInjection.h"
#import "AppKitRedeclaration.h"
#import <dlfcn.h>
#import <objc/runtime.h>
#include <libproc.h>

const char *wantsIndicatorFile = "/Users/Shared/.recordingIndicator/wants_indicator";
const char *wantsCCOnlyFile = "/Users/Shared/.recordingIndicator/wants_cc_only";
const char *wantsDebugColorFile = "/Users/Shared/.recordingIndicator/wants_debug_color";
static NSString *exceptionsPlistFile = @"/Users/Shared/.recordingIndicator/exceptions.plist";
static NSString *currentSourcesPlistFile = @"/Users/Shared/.recordingIndicator/candidate_sources.plist";

// From https://developer.limneos.net/index.php?ios=14.4&framework=SystemStatus.framework&header=STMediaStatusDomainData.h
@interface STMediaStatusDomainData : NSObject
@property (nonatomic, copy, readonly) NSSet *audioRecordingAttributions;
@end

// From https://developer.limneos.net/?ios=14.4&framework=SystemStatus.framework&header=STActivityAttribution.h
@interface STActivityAttribution : NSObject
@property (nonatomic, readonly) int pid;
@end

static BOOL isWindowServer = NO;
static BOOL isControlCenter = NO;
static NSHashTable<NSPrivacyIndicatorView *> *cachedPrivacyIndicatorViews;
static NSHashTable<NSPanel *> *cachedPrivacyIndicatorPanels;

NSString *pathForPID(pid_t pid) {
    int ret;
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    
    ret = proc_pidpath (pid, pathbuf, sizeof(pathbuf));
    if (ret > 0) {
        NSString *pathString = [NSString stringWithUTF8String:pathbuf];
        return pathString.length ? pathString : nil;
    }
    
    return nil;
}

NSString *normalizedPathForPath(NSString *path) {
    static NSString *separator = @"/Contents/MacOS";
    NSMutableArray *components = [path componentsSeparatedByString:separator].mutableCopy;
    if (components.count > 1) {
        [components removeLastObject];
        NSString *joinedPath = [components componentsJoinedByString:separator];
        return joinedPath;
    }
    return path;
}

NSString *bundleIDForNormalizedPath(NSString *path) {
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    return bundle.bundleIdentifier;
}

@implementation NSObject (RecordingIndicatorInjection)

+ (void)load {
    NSLog(@"[RecordingIndicatorInjection] Injected.");
    const char* currentprocname = getprogname();
    isWindowServer = strcmp("WindowServer", currentprocname) == 0;
    isControlCenter = strcmp("ControlCenter", currentprocname) == 0;
    if (!isWindowServer && !isControlCenter) {
        NSLog(@"[RecordingIndicatorInjection] The injected process is neither WindowServer nor ControlCenter. Skipping.");
        return;
    }
    
    void *handle = dlopen("/System/Library/PrivateFrameworks/SystemStatus.framework/Versions/A/SystemStatus", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "[RecordingIndicatorInjection] Cannot dlopen SystemStatus, error %s.\n", dlerror());
    }
    
    Class domainDataClass = NSClassFromString(@"STMediaStatusDomainData");
    NSLog(@"[RecordingIndicatorInjection] STMediaStatusDomainData is %@.", domainDataClass);
    Method origMethod = class_getInstanceMethod(domainDataClass, @selector(audioRecordingAttributions));
    Method newMethod = class_getInstanceMethod(domainDataClass, @selector(_zero_audioRecordingAttributions));
    method_exchangeImplementations(origMethod, newMethod);
    
    if (!isControlCenter) {
        return;
    }
    
    cachedPrivacyIndicatorPanels = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    Class panelClass = NSClassFromString(@"NSPanel");
    NSLog(@"[RecordingIndicatorInjection] panelClass = %@", panelClass);
    if (panelClass) {
        Method origSetTitleMethod = class_getInstanceMethod(panelClass, @selector(setTitle:));
        Method newSetTitleMethod = class_getInstanceMethod(panelClass, @selector(_zero_setTitle:));
        method_exchangeImplementations(origSetTitleMethod, newSetTitleMethod);
    }
    
    cachedPrivacyIndicatorViews = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    Class privacyIndicatorViewClass = NSClassFromString(@"NSPrivacyIndicatorView");
    NSLog(@"[RecordingIndicatorInjection] privacyIndicatorViewClass = %@", privacyIndicatorViewClass);
    if (privacyIndicatorViewClass) {
        Method origIndicatorMethod = class_getInstanceMethod(privacyIndicatorViewClass, @selector(initWithFrame:));
        Method newIndicatorMethod = class_getInstanceMethod(privacyIndicatorViewClass, @selector(_zero_initWithFrame:));
        method_exchangeImplementations(origIndicatorMethod, newIndicatorMethod);
    }
}

// Caching SensorIndicators NSPanel (macOS 12.1 and earlier)
- (void)_zero_setTitle:(NSString *)title {
    [self _zero_setTitle:title];
    if ([title isEqualToString:@"SensorIndicators"]) {
        NSLog(@"[RecordingIndicatorInjection] In swizzled setTitle: for NSPanel with SensorIndicators title");
        [cachedPrivacyIndicatorPanels addObject:(NSPanel *)self];
        BOOL wantsCCOnly = access(wantsCCOnlyFile, F_OK) == 0;
        [self updateCachedPrivacyIndicatorViewForWantsFill:wantsCCOnly];
    }
}

// Caching NSPrivacyIndicatorView (macOS 12.2 and later)
- (instancetype)_zero_initWithFrame:(NSRect)frameRect {
    NSView *initialized = (NSView *)[self _zero_initWithFrame:frameRect];
    if ([NSStringFromClass(initialized.class) isEqualToString:@"NSPrivacyIndicatorView"]) {
        NSLog(@"[RecordingIndicatorInjection] In swizzled initWithFrame: for NSPrivacyIndicatorView");
        [cachedPrivacyIndicatorViews addObject:(NSPrivacyIndicatorView *)initialized];
        BOOL wantsCCOnly = access(wantsCCOnlyFile, F_OK) == 0;
        [self updateCachedPrivacyIndicatorViewForWantsFill:wantsCCOnly];
    }
    return initialized;
}

- (void)updateCachedPrivacyIndicatorViewForWantsFill:(BOOL)wantsFill {
    if (!isControlCenter) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSPanel *indicatorPanel in cachedPrivacyIndicatorPanels) {
            NSView *view = indicatorPanel.contentView;
            NSLog(@"[RecordingIndicatorInjection] Updating indicator content view %@, hidden = %d", view, wantsFill);
            view.layer.opacity = wantsFill ? 0 : 1;
        }
        BOOL wantsDebugColor = access(wantsDebugColorFile, F_OK) == 0;
        for (NSView *cachedPrivacyIndicatorView in cachedPrivacyIndicatorViews) {
            NSLog(@"[RecordingIndicatorInjection] Update cached privacy indicator view for wants fill %d", wantsFill);
            cachedPrivacyIndicatorView.wantsLayer = YES;
            cachedPrivacyIndicatorView.layer.masksToBounds = wantsFill;
            if (wantsFill) {
                if (wantsDebugColor) {
                    cachedPrivacyIndicatorView.layer.backgroundColor = [NSClassFromString(@"NSColor") colorWithSRGBRed:29/255.0 green:148/255.0 blue:246/255.0 alpha:1].CGColor;
                } else {
                    // Counteract lowered opacity with a brighter color.
                    cachedPrivacyIndicatorView.layer.backgroundColor = [NSClassFromString(@"NSColor") colorWithSRGBRed:255/255.0 green:133/255.0 blue:0/255.0 alpha:1].CGColor;
                }
            } else {
                cachedPrivacyIndicatorView.layer.backgroundColor = nil;
            }
            
            // This isn't perfect. On 2x the view is 5x5, so 2.5 radius is a perfect circle.
            // On 1x the view is 5x4, so it becomes an oval.
            cachedPrivacyIndicatorView.layer.cornerRadius = wantsFill ? 2.5 : 0;
            cachedPrivacyIndicatorView.layer.cornerCurve = kCACornerCurveContinuous;
        }
    });
}

- (NSSet *)_zero_audioRecordingAttributions {
    NSLog(@"[RecordingIndicatorInjection] Client asked for audio recording attributions");
    
    if (access(wantsIndicatorFile, F_OK) != 0) {
        NSLog(@"[RecordingIndicatorInjection] wants_indicator doesn't exist, returning empty set");
        return [NSSet set];
    }
    
    BOOL wantsCCOnly = access(wantsCCOnlyFile, F_OK) == 0;
    [self updateCachedPrivacyIndicatorViewForWantsFill:wantsCCOnly];
    if (isWindowServer && wantsCCOnly) {
        NSLog(@"[RecordingIndicatorInjection] wants_cc_only exists, returning empty set for WindowServer");
        return [NSSet set];
    }
    
    NSLog(@"[RecordingIndicatorInjection] wants_indicator file exists, checking original attributions.");
    NSSet *originalAttributions = [self _zero_audioRecordingAttributions];
    NSLog(@"[RecordingIndicatorInjection] Original attributions are %@", originalAttributions);
    NSMutableSet *attributions = [originalAttributions mutableCopy];
    
    NSMutableArray *exceptionsArray = [[NSArray arrayWithContentsOfFile:exceptionsPlistFile] mutableCopy] ?: [NSMutableArray array];
    // Recording Indicator Utility may make a 0 second long recording to force WindowServer and Control Center
    // refresh their recording indicators. Because no actual audio is recorded or saved, drop the attribution
    // for Recording Indicator Utility to prevent the orange dot from flashing.
    [exceptionsArray addObject:@{
        @"binaryName" : @"Recording Indicator Utility",
        @"bundleIdentifier" : @"com.mac.RecordingIndicatorUtility",
        @"bundleName" : @"Recording Indicator Utility",
        @"enabled" : @YES,
    }];
    NSLog(@"[RecordingIndicatorInjection] Exceptions array is %@", exceptionsArray);
    
    NSMutableArray *candidateSources = [NSMutableArray array];
    for (STActivityAttribution *attribution in originalAttributions) {
        if (![attribution respondsToSelector:@selector(pid)]) {
            continue;
        }
        pid_t pid = attribution.pid;
        NSString *path = pathForPID(pid);
        NSLog(@"[RecordingIndicatorInjection] Path = %@", path);
        if (!path.length) {
            NSLog(@"[RecordingIndicatorInjection] Removing stale attribution %@.", attribution);
            [attributions removeObject:attribution];
            continue;
        }
        NSString *normalizedPath = normalizedPathForPath(path);
        if (normalizedPath.length) {
            [candidateSources addObject:normalizedPath];
        }
        NSLog(@"[RecordingIndicatorInjection] Normalized path = %@", normalizedPath);
        NSString *bundleID = bundleIDForNormalizedPath(normalizedPath);
        NSLog(@"[RecordingIndicatorInjection] Bundle ID = %@", bundleID);
        
        for (NSDictionary *exception in exceptionsArray) {
            NSNumber *exceptionEnablement = exception[@"enabled"];
            if ([exceptionEnablement respondsToSelector:@selector(boolValue)] && !exceptionEnablement.boolValue) {
                NSLog(@"[RecordingIndicatorInjection] Skipping %@ which isn't enabled.", exception);
                continue;
            }
            NSString *exceptionBinaryName = exception[@"binaryName"];
            NSString *exceptionBundleIdentifier = exception[@"bundleIdentifier"];
            NSString *exceptionBundleName = exception[@"bundleName"];
            NSString *exceptionPath = exception[@"path"];
            NSLog(@"[RecordingIndicatorInjection] Exception: %@, %@, %@, %@", exceptionBinaryName, exceptionBundleIdentifier, exceptionBundleName, exceptionPath);
            
            NSArray<NSString *> *pathComponents = path.pathComponents;
            if ([bundleID isEqualToString:exceptionBundleIdentifier] || (exceptionPath && [path hasPrefix:exceptionPath]) || [pathComponents containsObject:exceptionBinaryName] || [pathComponents containsObject:exceptionBundleName]) {
                NSLog(@"[RecordingIndicatorInjection] Removing attribution %@ for %@ (%@) in the exception list", attribution, normalizedPath, bundleID);
                [attributions removeObject:attribution];
                if (normalizedPath.length) {
                    [candidateSources removeObject:normalizedPath];
                }
            }
        }
    }
    
    [candidateSources writeToFile:currentSourcesPlistFile atomically:NO];
    return attributions;
}

@end
