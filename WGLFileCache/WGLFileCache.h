//
//  WGLFileCache.h
//  WGLFileCache
//
//  Created by wugl on 2019/2/21.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WGLFileCache : NSObject

//缓存单例
+ (instancetype)sharedCache;

/**
 获取缓存key

 @param url NSURL
 @return 缓存key
 */
- (NSString *)cacheKeyForURL:(NSURL *)url;

/**
 缓存数据到内存和磁盘

 @param data NSData
 @param key 缓存key
 @return 缓存结果
 */
- (BOOL)storeCache:(NSData *)data forKey:(NSString *)key;

/**
 缓存数据到磁盘

 @param data NSData
 @param key 缓存key
 @return 缓存结果
 */
- (BOOL)storeCacheToDisk:(NSData *)data forKey:(NSString *)key;

/**
 获取缓存

 @param key 缓存key
 @param completion 缓存数据
 */
- (void)getCacheForKey:(NSString *)key completion:(void(^)(NSData *cache))completion;

/**
 删除缓存从内存和磁盘

 @param key 缓存key
 @return 删除结果
 */
- (BOOL)removeCacheForKey:(NSString *)key;

/**
 删除缓存从磁盘

 @param key 缓存key
 @return 删除结果
 */
- (BOOL)removeCacheFromDiskForKey:(NSString *)key;

/**
 清空所有缓存从内存和磁盘
 */
- (void)clearAllCache;

/**
 清空所有缓存从磁盘
 */
- (void)clearAllCacheInDisk;

/**
 缓存是否存在于内存或者磁盘

 @param key 缓存key
 @return YES-缓存存在，NO-缓存不存在
 */
- (BOOL)cacheExistForKey:(NSString *)key;

/**
 缓存是否存在于磁盘

 @param key 缓存key
 @return YES-缓存存在，NO-缓存不存在
 */
- (BOOL)cacheExistInDiskForKey:(NSString *)key;

/**
 缓存的路径

 @param key 缓存key
 @param directory 缓存的目录
 @return 缓存的完整路径
 */
- (NSString *)cachePathForKey:(NSString *)key inDirectory:(NSString *)directory;

/**
 缓存的默认路径

 @param key 缓存key
 @return 缓存的完整路径
 */
- (NSString *)defaultCachePathForKey:(NSString *)key;

/**
 缓存的文件名

 @param key 缓存key
 @return 缓存的文件名
 */
- (NSString *)cachedFileNameForKey:(NSString *)key;

@end
