#import "AliPushSDKProxy.h"
#import <CloudPushSDK/CloudPushSDK.h>

// 阿里云推送 SDK 的所有调用都收敛在此 .mm 编译单元内。Swift 侧只看到
// `AliPushSDKProxy.h`（纯 Foundation，不引用 CloudPushSDK.h），因此 CloudPushSDK
// 内部的 libc++ 头（cstddef 等）与 framework 的 non-modular header 不会被 Swift
// 的编译上下文加载。

@implementation AliPushSDKProxy

+ (instancetype)shared {
  static AliPushSDKProxy *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[AliPushSDKProxy alloc] init];
  });
  return instance;
}

- (nullable NSString *)getDeviceId {
  return [CloudPushSDK getDeviceId];
}

- (void)bindAccount:(NSString *)account completion:(AliPushSimpleCallback)completion {
  [CloudPushSDK bindAccount:account withCallback:^(CCPSysMessage *res) {
    completion(res.success, res.error.localizedDescription);
  }];
}

- (void)unbindAccountWithCompletion:(AliPushSimpleCallback)completion {
  [CloudPushSDK unbindAccount:^(CCPSysMessage *res) {
    completion(res.success, res.error.localizedDescription);
  }];
}

- (void)bindTag:(int32_t)target
           tags:(NSArray<NSString *> *)tags
          alias:(nullable NSString *)alias
     completion:(AliPushSimpleCallback)completion {
  [CloudPushSDK bindTag:target withTags:tags withAlias:alias withCallback:^(CCPSysMessage *res) {
    completion(res.success, res.error.localizedDescription);
  }];
}

- (void)unbindTag:(int32_t)target
             tags:(NSArray<NSString *> *)tags
            alias:(nullable NSString *)alias
       completion:(AliPushSimpleCallback)completion {
  [CloudPushSDK unbindTag:target withTags:tags withAlias:alias withCallback:^(CCPSysMessage *res) {
    completion(res.success, res.error.localizedDescription);
  }];
}

- (void)listTags:(int32_t)target completion:(AliPushDataCallback)completion {
  [CloudPushSDK listTags:target withCallback:^(CCPSysMessage *res) {
    NSString *dataStr = [res.data isKindOfClass:[NSString class]] ? (NSString *)res.data : nil;
    completion(res.success, res.error.localizedDescription, dataStr);
  }];
}

- (void)addAlias:(NSString *)alias completion:(AliPushSimpleCallback)completion {
  [CloudPushSDK addAlias:alias withCallback:^(CCPSysMessage *res) {
    completion(res.success, res.error.localizedDescription);
  }];
}

- (void)removeAlias:(NSString *)alias completion:(AliPushSimpleCallback)completion {
  [CloudPushSDK removeAlias:alias withCallback:^(CCPSysMessage *res) {
    completion(res.success, res.error.localizedDescription);
  }];
}

- (void)listAliasesWithCompletion:(AliPushDataCallback)completion {
  [CloudPushSDK listAliases:^(CCPSysMessage *res) {
    NSString *dataStr = [res.data isKindOfClass:[NSString class]] ? (NSString *)res.data : nil;
    completion(res.success, res.error.localizedDescription, dataStr);
  }];
}

- (void)syncBadgeNum:(NSUInteger)badge completion:(AliPushSimpleCallback)completion {
  [CloudPushSDK syncBadgeNum:badge withCallback:^(CCPSysMessage *res) {
    completion(res.success, res.error.localizedDescription);
  }];
}

@end
