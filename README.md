# react-native-nitro-ali-push

阿里云移动推送（Alibaba Cloud Push）的 React Native 封装，基于 **Nitro Modules** 实现：

- iOS 原生端：**Swift**（`HybridAliPushPlugin` 实现 Nitro 生成的 `HybridAliPushPluginSpec`）
- Android 原生端：**Kotlin**（`HybridAliPushPlugin` 继承 Nitro 生成的 `HybridAliPushPluginSpec`）
- 原生桥接层由 `nitrogen` 代码生成器生成，无需手写 C++ / JNI / Objective-C
- 推送事件通过 Nitro 回调（`addListener` 返回退订闭包）直接派发，不再依赖 `NativeEventEmitter`

> 旧版（基于 TurboModule + 经典 bridge interop）位于 `react-native-ali-push`，本库为其 Nitro 重构版。

---

## 要求

| 依赖 | 版本 |
| --- | --- |
| react-native | >= 0.76（新架构） |
| react | * |
| react-native-nitro-modules | >= 0.37.0 |
| Android | `minSdk 21`、`compileSdk 34` |
| iOS | `13.0+`、Xcode 14+ |

---

## 安装

```bash
npm install react-native-nitro-ali-push
# 或
yarn add react-native-nitro-ali-push
```

iOS 需要执行：

```bash
cd ios && pod install
```

---

## iOS 集成

### 1. 引入阿里云推送 SDK（`CloudPushSDK`）

**方式一：CocoaPods（默认，推荐）**

阿里云推送的 pod 不在 CocoaPods trunk，而在官方自己的 spec 仓库，所以要先在 `ios/Podfile` **顶部**声明 source：

```ruby
source 'https://github.com/aliyun/aliyun-specs.git'
source 'https://cdn.cocoapods.org/'
```

若本机还没添加过该仓库，先执行一次：

```bash
pod repo add AliyunRepo https://github.com/aliyun/aliyun-specs.git
```

本库 podspec 默认已声明 `s.dependency "AlicloudPush", "~> 3"`，因此无需再做其它配置，直接 `pod install` 即可。

**方式二：手动集成**

从 [阿里云移动推送控制台](https://push.console.aliyun.com/) 下载 iOS SDK，把 `CloudPushSDK.framework`（3.x 为 `CloudPushSDK.xcframework`）放到本库 `ios/` 目录下。
podspec 检测到该文件后会自动改用 `vendored_frameworks`，不再依赖 `AlicloudPush`，无需修改 podspec。

> 若 `pod install` 报 `Unable to find a specification for 'AlicloudPush'`，说明 Podfile 里缺少上面的阿里云 source。

### 2. AppDelegate 中初始化

iOS 端的推送初始化必须在原生层完成（不能在 JS 中 `initPush`）：

```swift
import UIKit
import UserNotifications
// 本库模块名由 podspec 名 react-native-nitro-ali-push 推导为 react_native_nitro_ali_push。
// HybridAliPushPlugin 是 public，跨模块使用需 import 本库模块（不在 NitroAliPush）。
import react_native_nitro_ali_push

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // ... 其他初始化（RCTBridge 等）...

    // 初始化阿里云推送
    HybridAliPushPlugin.shared().setParams(
      "<appKey>",
      appSecret: "<appSecret>",
      lauchOptions: launchOptions as? [AnyHashable: Any],
      createNotificationCategoryHandler: {}
    )

    return true
  }

  // 注册 deviceToken
  func application(_ application: UIApplication,
                  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    HybridAliPushPlugin.shared().application(application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func application(_ application: UIApplication,
                  didFailToRegisterForRemoteNotificationsWithError error: Error) {
    HybridAliPushPlugin.shared().application(application,
      didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // 收到远程通知
  func application(_ application: UIApplication,
                  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    HybridAliPushPlugin.shared().application(application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler)
  }
}
```

> 若 CocoaPods 编译时提示找不到 `React` / `CloudPushSDK` 模块，请在 Podfile 中开启 `use_frameworks!` 或 `use_modular_headers!`。

---

## Android 集成

### 1. `AndroidManifest.xml` 配置 AppKey / AppSecret

在 `Application` 节点下（或 `MainApplication`）添加 `meta-data`：

```xml
<application ...>
  <meta-data android:name="com.alibaba.app.appkey" android:value="<appKey>" />
  <meta-data android:name="com.alibaba.app.appsecret" android:value="<appSecret>" />
</application>
```

### 2. 初始化

Android 端在 JS 中调用 `initPush` 即可：

```ts
import AliPush from 'react-native-nitro-ali-push';

await AliPush.initPush('<appKey>', '<appSecret>');
```

---

## 用法

### 订阅推送消息

```ts
import AliPush from 'react-native-nitro-ali-push';

const unsubscribe = AliPush.addEventListener('aliyunPushReceived', (message) => {
  console.log(message.title, message.body, message.extras, message.type);
});

// ... 不再需要时
unsubscribe();
```

### 账号 / 标签 / 别名

```ts
await AliPush.bindAccount('user_001');
await AliPush.unbindAccount();

await AliPush.bindTag(1, ['news', 'sports'], null); // target: 1 设备 / 2 账号 / 3 别名
await AliPush.unbindTag(1, ['news'], null);

await AliPush.addAlias('alias_001');
await AliPush.removeAlias('alias_001');

const tags = await AliPush.listTags(1);
const aliases = await AliPush.listAliases();
```

### 设备号与角标

```ts
const deviceId = await AliPush.getDeviceId();

await AliPush.setApplicationIconBadgeNumber(0);
const badge = await AliPush.getApplicationIconBadgeNumber();
```

---

## API 参考

所有方法均返回 `Promise`（除事件订阅）。详见源码 `src/index.ts` 的 JSDoc。

| 方法 | 说明 | 平台差异 |
| --- | --- | --- |
| `initPush(appKey, appSecret)` | 初始化推送 | Android 必需；iOS 为无操作（在 AppDelegate 初始化） |
| `getDeviceId()` | 获取设备 `deviceId` | — |
| `bindAccount(account)` | 绑定账号 | — |
| `unbindAccount()` | 解绑账号 | — |
| `bindTag(target, tags, alias)` | 绑定标签 | `target`: 1 设备 / 2 账号 / 3 别名 |
| `unbindTag(target, tags, alias)` | 解绑标签 | 同上 |
| `listTags(target)` | 列出标签 | 返回服务端响应字符串 |
| `addAlias(alias)` / `removeAlias(alias)` | 添加 / 移除别名 | — |
| `listAliases()` | 列出别名 | 返回服务端响应字符串 |
| `setApplicationIconBadgeNumber(badge)` | 设置角标 | — |
| `getApplicationIconBadgeNumber()` | 获取角标 | — |
| `getInitialMessage()` | 获取冷启动首条消息 | 无则 `null` |
| `getAuthorizationStatus()` | 获取通知授权状态 | Android 返回系统通知权限实际状态 |
| `syncBadgeNum(badge)` | 同步角标到服务端 | 仅 iOS 有效 |
| `addEventListener(event, listener)` | 订阅 `aliyunPushReceived` | 返回退订函数 |
| `removeEventListener(unsubscribe)` | 取消订阅 | — |

事件载荷类型见 `src/types.ts` 的 `AliPushMessage`。

---

## 开发 / 重新生成原生代码

修改 `src/specs/*.nitro.ts` 后，运行代码生成器重新产出原生桥接层：

```bash
npm run codegen   # 等价于 npx nitrogen
```

类型检查：

```bash
npm run typecheck   # tsc --noEmit
```

本库源码（含类型与 JSDoc）位于 `src/`，原生端位于 `android/` 与 `ios/`，生成的桥接代码位于 `nitrogen/generated/`（随包发布，消费者无需自行运行 codegen）。Metro 会直接使用 `src/index.ts`（`package.json` 的 `source` / `react-native` 字段）。

## License

[MIT](./LICENSE) © hengkx &lt;ycxzhkx@gmail.com&gt;

仓库与问题反馈：<https://github.com/hengkx/react-native-nitro-ali-push>
