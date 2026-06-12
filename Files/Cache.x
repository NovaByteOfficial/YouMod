#import "Headers.h"

// Auto clear cache
%hook YTAppDelegate

%new
- (void)YouModAutoClearCache {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;

    if (cachePath.length == 0) {
        return;
    }

    NSError *directoryError = nil;
    NSArray<NSString *> *items = [fileManager contentsOfDirectoryAtPath:cachePath error:&directoryError];
    if (directoryError || items.count == 0) {
        return;
    }

    for (NSString *item in items) {
        NSString *itemPath = [cachePath stringByAppendingPathComponent:item];
        [fileManager removeItemAtPath:itemPath error:nil];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    if (IS_ENABLED(AutoClearCache)) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [self YouModAutoClearCache];
        });
    }

    return result;
}

%end
