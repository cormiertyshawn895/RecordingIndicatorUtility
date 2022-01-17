//
//  NSObject+RecordingIndicatorInjection.m
//  RecordingIndicatorInjection
//

#import "NSObject+RecordingIndicatorInjection.h"
#import <dlfcn.h>
#import <objc/runtime.h>

const char *wantsIndicatorFile = "/Users/Shared/.recordingIndicator/wants_indicator";

// From https://developer.limneos.net/index.php?ios=14.4&framework=SystemStatus.framework&header=STMediaStatusDomainData.h
@interface STMediaStatusDomainData : NSObject
@property (nonatomic, copy, readonly) NSSet *audioRecordingAttributions;
@end

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
        return [self _zero_audioRecordingAttributions];
    }

    NSLog(@"[RecordingIndicatorInjection] wants_indicator doesn't exist, returning empty set");
    return [NSSet set];
}

@end
