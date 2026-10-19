#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 轻量结果回调：成功 / 失败（失败时的错误信息）。
typedef void (^AliPushSimpleCallback)(BOOL success, NSString *_Nullable error);

/// 带 `data` 字符串的结果回调（listTags / listAliases 用，服务端以逗号拼接返回）。
typedef void (^AliPushDataCallback)(BOOL success, NSString *_Nullable error, NSString *_Nullable data);

/**
 * 阿里云推送 SDK 的轻量封装协议。
 *
 * Swift 侧（`HybridAliPushPlugin`）**只依赖此协议**，不直接 `import CloudPushSDK`，
 * 从而阻断 CloudPushSDK 内部 libc++ 头（`cstddef` 等）对 Swift 编译上下文的污染，
 * 以及 framework 的 non-modular header 问题。
 *
 * 具体实现见 `AliPushSDKProxy.mm`——它内部 `#import <CloudPushSDK/CloudPushSDK.h>`，
 * 把 CloudPushSDK 的回调式 API 包成上面的 block 接口。由于本头文件不引用
 * CloudPushSDK.h，被 Swift 的 umbrella header 包含时也不会把阿里云头带进来。
 */
@protocol AliPushSDKProxying <NSObject>

- (nullable NSString *)getDeviceId;

- (void)bindAccount:(NSString *)account completion:(AliPushSimpleCallback)completion;
- (void)unbindAccountWithCompletion:(AliPushSimpleCallback)completion;

- (void)bindTag:(int32_t)target
           tags:(NSArray<NSString *> *)tags
          alias:(nullable NSString *)alias
     completion:(AliPushSimpleCallback)completion;
- (void)unbindTag:(int32_t)target
             tags:(NSArray<NSString *> *)tags
            alias:(nullable NSString *)alias
       completion:(AliPushSimpleCallback)completion;

- (void)listTags:(int32_t)target completion:(AliPushDataCallback)completion;

- (void)addAlias:(NSString *)alias completion:(AliPushSimpleCallback)completion;
- (void)removeAlias:(NSString *)alias completion:(AliPushSimpleCallback)completion;

- (void)listAliasesWithCompletion:(AliPushDataCallback)completion;

- (void)syncBadgeNum:(NSUInteger)badge completion:(AliPushSimpleCallback)completion;

@end

/// 默认实现：单例，内部 `import <CloudPushSDK/CloudPushSDK.h>`。
@interface AliPushSDKProxy : NSObject <AliPushSDKProxying>
+ (instancetype)shared;
@end

NS_ASSUME_NONNULL_END
