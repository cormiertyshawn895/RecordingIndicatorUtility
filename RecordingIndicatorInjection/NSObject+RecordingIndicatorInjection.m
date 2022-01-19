//
//  NSObject+RecordingIndicatorInjection.m
//  RecordingIndicatorInjection
//

#import "NSObject+RecordingIndicatorInjection.h"
#import <dlfcn.h>
#include <libproc.h>
#import <objc/runtime.h>

const char *wantsIndicatorFile = "/Users/Shared/.recordingIndicator/wants_indicator";

// From https://developer.limneos.net/index.php?ios=14.4&framework=SystemStatus.framework&header=STMediaStatusDomainData.h
@interface STMediaStatusDomainData : NSObject
@property (nonatomic, copy, readonly) NSSet *audioRecordingAttributions;
@end

// From https://developer.limneos.net/?ios=14.4&framework=SystemStatus.framework&header=STActivityAttribution.h
@interface STActivityAttribution : NSObject
@property (nonatomic, readonly) int pid;
@end

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

NSString *bundleIDForPath(NSString *path) {
    static NSString *separator = @"/Contents/MacOS";
    NSMutableArray *components = [path componentsSeparatedByString:separator].mutableCopy;
    if (components.count > 1) {
        [components removeLastObject];
    }
    NSBundle *bundle = [NSBundle bundleWithPath:[components componentsJoinedByString:separator]];
    return bundle.bundleIdentifier;
}

@implementation NSObject (RecordingIndicatorInjection)

+ (void)load {
    NSLog(@"[RecordingIndicatorInjection] Injected.");
    const char* currentprocname = getprogname();
    if (strcmp("WindowServer", currentprocname) != 0 && strcmp("ControlCenter", currentprocname) != 0) {
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
}

- (NSSet *)_zero_audioRecordingAttributions {
    NSLog(@"[RecordingIndicatorInjection] Client asked for audio recording attributions");

    if (access(wantsIndicatorFile, F_OK) == 0) {
        NSLog(@"[RecordingIndicatorInjection] wants_indicator file exists, return original attributions.");
        NSSet *originalAttributions = [self _zero_audioRecordingAttributions];
        NSLog(@"[RecordingIndicatorInjection] Original attributions are %@", originalAttributions);
        NSMutableSet *attributions = [originalAttributions mutableCopy];
        // Recording Indicator Utility may make a 0 second long recording to force WindowServer and Control Center
        // refresh their recording indicators. Because no actual audio is recorded or saved, drop the attribution
        // for Recording Indicator Utility to prevent the orange dot from flashing.
        if (originalAttributions.count > 0) {
            for (STActivityAttribution *attribution in originalAttributions) {
                if ([attribution respondsToSelector:@selector(pid)]) {
                    pid_t pid = attribution.pid;
                    NSString *path = pathForPID(pid);
                    NSLog(@"[RecordingIndicatorInjection] Path = %@", path);
                    NSString *bundleID = bundleIDForPath(path);
                    NSLog(@"[RecordingIndicatorInjection] Bundle ID = %@", bundleID);
                    if ([bundleID isEqualToString:@"com.mac.RecordingIndicatorUtility"] || [path containsString:@"Recording Indicator Utility"]) {
                        [attributions removeObject:attribution];
                    }
                }
            }
        }
        return attributions;
    }

    NSLog(@"[RecordingIndicatorInjection] wants_indicator doesn't exist, returning empty set");
    return [NSSet set];
}

@end
