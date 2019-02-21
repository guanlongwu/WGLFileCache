//
//  WGLFileCache.m
//  WGLFileCache
//
//  Created by wugl on 2019/2/21.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import "WGLFileCache.h"
#import <CommonCrypto/CommonDigest.h>

static const NSString *kCacheDefaultName = @"defaultNameForHYFileCache";

@interface WGLFileCache ()
@property (nonatomic, strong) dispatch_queue_t ioQueue;//io操作队列
@property (nonatomic, strong) NSCache *memCache;
@property (nonatomic, strong) NSString *cacheDirectory;//磁盘缓存路径
@end

@implementation WGLFileCache

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)sharedCache {
    static WGLFileCache *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _memCache = [[NSCache alloc] init];
        _ioQueue = dispatch_queue_create("com.wugl.WGLFileCache.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)storeCache:(NSData *)data forKey:(NSString *)key {
    if (!data || key.length == 0) {
        return NO;
    }
    [self.memCache setObject:data forKey:key];
    BOOL result = NO;
    @autoreleasepool {
        result = [self storeCacheToDisk:data forKey:key];
    }
    return result;
}

- (BOOL)storeCacheToDisk:(NSData *)data forKey:(NSString *)key {
    if (!data || key.length == 0) {
        return NO;
    }
    dispatch_async(self.ioQueue, ^{
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.cacheDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        NSString *cachePathForKey = [self defaultCachePathForKey:key];
        [[NSFileManager defaultManager] createFileAtPath:cachePathForKey contents:data attributes:nil];
    });
    return YES;
}

- (void)getCacheForKey:(NSString *)key completion:(void(^)(NSData *cache))completion {
    if (key.length == 0) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    dispatch_async(self.ioQueue, ^{
        //首先取缓存
        NSData *diskData = [self.memCache objectForKey:key];
        if (!diskData) {
            //缓存没有，取磁盘
            @autoreleasepool {
                diskData = [self diskFileDataBySearchingAllPathsForKey:key];
            }
        }
        if (completion) {
            completion(diskData);
        }
    });
}

- (BOOL)removeCacheForKey:(NSString *)key {
    if (key.length == 0) {
        return NO;
    }
    [self.memCache removeObjectForKey:key];
    BOOL result = [self removeCacheFromDiskForKey:key];
    return result;
}

- (BOOL)removeCacheFromDiskForKey:(NSString *)key {
    if (key.length == 0) {
        return NO;
    }
    dispatch_async(self.ioQueue, ^{
        NSError *error = nil;
        BOOL result = [[NSFileManager defaultManager] removeItemAtPath:[self defaultCachePathForKey:key] error:&error];
        BOOL success = (result && error == nil);
        if (NO == success) {
            
        }
    });
    return YES;
}

- (void)clearAllCache {
    [self.memCache removeAllObjects];
    [self clearAllCacheInDisk];
}

- (void)clearAllCacheInDisk {
    dispatch_async(self.ioQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:self.cacheDirectory error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
}

- (BOOL)cacheExistForKey:(NSString *)key {
    if (key.length == 0) {
        return NO;
    }
    NSData *data = [self.memCache objectForKey:key];
    if (!data) {
        return [self cacheExistInDiskForKey:key];
    }
    return YES;
}

- (BOOL)cacheExistInDiskForKey:(NSString *)key {
    if (key.length == 0) {
        return NO;
    }
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForKey:key]];
    if (!exists) {
        exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForKey:key].stringByDeletingPathExtension];
    }
    if (exists) {
        //磁盘有，则缓存一份到内存
        dispatch_async(self.ioQueue, ^{
            [self getCacheForKey:key completion:^(NSData *cache) {
                if (cache) {
                    [self.memCache setObject:cache forKey:key];
                }
            }];
        });
    }
    return exists;
}

//获取Key对应的文件缓存
- (nullable NSData *)diskFileDataBySearchingAllPathsForKey:(nullable NSString *)key {
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [self diskFileDataBySearchingAllPathsForPath:defaultPath];
    return data;
}

//获取路径下的文件缓存
- (nullable NSData *)diskFileDataBySearchingAllPathsForPath:(nullable NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:nil];
    if (data) {
        return data;
    }
    data = [NSData dataWithContentsOfFile:path.stringByDeletingPathExtension options:NSDataReadingUncached error:nil];
    if (data) {
        return data;
    }
    return nil;
}

#pragma mark - private

- (void)checkIfQueueIsIOQueue {
    const char *currentQueueLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    const char *ioQueueLabel = dispatch_queue_get_label(self.ioQueue);
    if (strcmp(currentQueueLabel, ioQueueLabel) != 0) {
        NSLog(@"This method should be called from the ioQueue");
    }
}

#pragma mark - Cache paths

- (NSString *)cachePathForKey:(NSString *)key inDirectory:(NSString *)directory {
    if (![[NSFileManager defaultManager] fileExistsAtPath:directory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSString *filename = [self cachedFileNameForKey:key];
    return [directory stringByAppendingPathComponent:filename];
}

- (NSString *)defaultCachePathForKey:(NSString *)key {
    return [self cachePathForKey:key inDirectory:self.cacheDirectory];
}

- (NSString *)cachedFileNameForKey:(NSString *)key {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!url) {
        return @"";
    }
    return url.absoluteString;
}

- (NSString *)cacheDirectory {
    if (!_cacheDirectory) {
        _cacheDirectory = [self makeDiskCachePath:[NSString stringWithFormat:@"%@", kCacheDefaultName]];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:_cacheDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:_cacheDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return _cacheDirectory;
}

- (NSString *)makeDiskCachePath:(NSString*)fullNamespace {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:fullNamespace];
}

#pragma mark - Cache Info

//获取磁盘缓存使用的大小。
- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:self.cacheDirectory];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.cacheDirectory stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

//获取磁盘缓存中的文件数量。
- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:self.cacheDirectory];
        count = fileEnumerator.allObjects.count;
    });
    return count;
}

//异步计算磁盘缓存的大小。
- (void)calculateSizeWithCompletionBlock:(void(^)(NSUInteger fileCount, NSUInteger totalSize))completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.cacheDirectory isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:diskCacheURL
                                                       includingPropertiesForKeys:@[NSFileSize]
                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                     errorHandler:NULL];
        
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

@end
