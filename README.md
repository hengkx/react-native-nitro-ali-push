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

### 2. 初始化（分两步）

按阿里云官方要求，初始化拆成两个阶段，本库已把第一阶段做成自动的：

| 阶段 | 做什么 | 何时发生 | 是否采集隐私 |
| --- | --- | --- | --- |
| ① 加载框架（官方「2.1 初始化」） | `PushServiceFactory.init(context)` —— 加载推送框架、初始化参数，**不启动推送逻辑** | 本库 `AliPushInitProvider` 自动完成，其 `onCreate` 早于 `Application.onCreate`，**宿主无需写任何原生代码** | 否 |
| ② 注册设备 | `CloudPushService.register(...)` —— 真正启动推送 | 你在 JS 里调用 `initPush` 时 | 是 |

因此在 JS 里只需做第 ② 步，且**建议在用户同意隐私政策之后再调用**：

```ts
import AliPush from 'react-native-nitro-ali-push';

// 代码方式
await AliPush.initPush('<appKey>', '<appSecret>');

// manifest 方式（AndroidManifest.xml 已配 appkey/appsecret）
// await AliPush.initPush();
```

> 注意：厂商通道（华为 / 小米 / OPPO / vivo / 魅族 / 荣耀）**不由 `initPush` 注册**，需要在宿主工程的原生层自行调用各厂商 `Register`。见下面「3. 厂商通道」。

### 3. 厂商通道（华为 / 小米 / OPPO / vivo / 魅族 / 荣耀）

本库的 `android/build.gradle` 已经 `api` 引入了辅助通道依赖：

```gradle
api 'com.aliyun.ams:alicloud-android-third-push:3.10.1'
api 'com.aliyun.ams:alicloud-android-third-push-huawei:3.10.1'
api 'com.aliyun.ams:alicloud-android-third-push-xiaomi:3.10.1'
api 'com.aliyun.ams:alicloud-android-third-push-oppo:3.10.1'
api 'com.aliyun.ams:alicloud-android-third-push-vivo:3.10.1'
api 'com.aliyun.ams:alicloud-android-third-push-meizu:3.10.1'
api 'com.aliyun.ams:alicloud-android-third-push-honor:3.10.1'
```

这些 `third-push-*` 依赖**不会自动注册任何厂商通道**。反编译 `alicloud-android-third-push:3.9.x` 的字节码已经验证：基础包和核心包里搜不到 `MIPUSH_APPID` 等 meta-data 字符串，阿里云模块自身完全不去读 manifest。每个厂商的 `XxxRegister` 都需要宿主**显式调用**一次（见下一小节）。

#### meta-data 写入示例

只有**华为 / 荣耀 / vivo**这三家的 appId 是由厂商自己的 SDK 从 manifest / `agconnect-services.json` 读取的，必须按下表写入 `AndroidManifest.xml` 的 `<application>` 节点内：

```xml
<!-- 华为：需额外放 agconnect-services.json 到工程根目录 -->
<meta-data
  android:name="com.huawei.hms.client.appid"
  android:value="appid=YOUR_HUAWEI_APP_ID" />

<!-- 荣耀 -->
<meta-data
  android:name="com.hihonor.push.app_id"
  android:value="YOUR_HIHONOR_APP_ID" />

<!-- vivo：由 vivo 自身 SDK 读取 -->
<meta-data android:name="com.vivo.push.app_id" android:value="YOUR_VIVO_APP_ID" />
<meta-data android:name="com.vivo.push.api_key" android:value="YOUR_VIVO_API_KEY" />
```

> 小米 / OPPO / 魅族**不需要**写这些 meta-data——它们的 appId/appKey 是你调用 `register(...)` 时直接传参的（见下）。若你选择把值存在 manifest 再自己读出来传参，注意纯数字会被 manifest 合并转成科学计数法（`123456789` → `1.23456789E8`），建议加 `id=` 前缀并在读取时去掉。

#### 注册方式：必须在宿主原生层自己调

**本库不提供厂商通道注册 API，`initPush` 也不会触发任何 `XxxRegister`。** 你必须自己在宿主工程的原生层（`MainApplication.onCreate`，且在 `PushServiceFactory.init(context)` **之后**）调用各厂商 `Register`。

| 厂商 | Register 类 | 调用方式 | appId / appKey 从哪来 |
| --- | --- | --- | --- |
| 华为 | `com.alibaba.sdk.android.push.huawei.HuaWeiRegister` | `register(application)` | HMS 自己读 `agconnect-services.json` + manifest |
| 荣耀 | `com.alibaba.sdk.android.push.HonorRegister` | `register(application)` | 荣耀 SDK 读 manifest `com.hihonor.push.app_id` |
| vivo | `com.alibaba.sdk.android.push.register.VivoRegister` | `register(context)` | vivo SDK 读 manifest `com.vivo.push.app_id` / `api_key` |
| 小米 | `com.alibaba.sdk.android.push.register.MiPushRegister` | `register(context, appId, appKey)` | **你自己传参** |
| OPPO | `com.alibaba.sdk.android.push.register.OppoRegister` | `register(context, appKey, appSecret)` | **你自己传参** |
| 魅族 | `com.alibaba.sdk.android.push.register.MeizuRegister` | `register(context, appId, appKey)` | **你自己传参** |

> 已实证：反编译 `alicloud-android-third-push:3.9.x` 全部模块，`com.xiaomi.push.id` / `com.oppo.push.key` / `com.meizu.push.id` 这些字符串在 SDK 里**搜不到**——阿里云 SDK 不会替你读它们。因此小米 / OPPO / 魅族这三家**必须由你显式传参**。若仍想用 manifest 存这些值，需自己用 `PackageManager.getApplicationInfo(...).metaData` 读出来再传给 `register`。

Kotlin 示例（`MainApplication.kt`）：

```kotlin
override fun onCreate() {
  super.onCreate()
  // 官方 2.1：此阶段只初始化推送参数，不启动推送逻辑
  PushServiceFactory.init(this)
  registerVendors()
}

private fun registerVendors() {
  val app = this

  // 华为 / 荣耀：需传 Application，appId 由厂商 SDK 自行读取
  com.alibaba.sdk.android.push.huawei.HuaWeiRegister.register(app)
  com.alibaba.sdk.android.push.HonorRegister.register(app)

  // vivo：无需传 appId，vivo SDK 自己读 manifest
  com.alibaba.sdk.android.push.register.VivoRegister.register(app)

  // 小米 / OPPO / 魅族：必须显式传 appId / appKey
  com.alibaba.sdk.android.push.register.MiPushRegister.register(app, MI_APP_ID, MI_APP_KEY)
  com.alibaba.sdk.android.push.register.OppoRegister.register(app, OPPO_KEY, OPPO_SECRET)
  com.alibaba.sdk.android.push.register.MeizuRegister.register(app, MEIZU_APP_ID, MEIZU_APP_KEY)
}
```

> 每个 `register` 内部都做了品牌判断，非本品牌设备会直接跳过，所以可以全部调用、不必自己判机型。若你没引入某个厂商的 `third-push-*` 模块，把对应那行删掉即可（否则编译报找不到类）。

**验证是否注册成功**：监听 `AliPushMessageReceiver.onChannelRegistration` 的日志（`onChannelRegistration: <errorCode>`）。errorCode 为 `0` 表示该厂商通道注册成功；非 `0` 通常是 appId/appKey 或厂商 SDK 没配齐。

**厂商通道通知点击**：走厂商系统通道下发的通知**不**经过阿里云的 `MessageReceiver`，而是通过厂商自己的点击 intent 拉起 App。本库提供了 `ThirdPartMessageActivity` 做中转（拉起后 `dispatchFromIntent` 把数据派发到 JS 的 `aliyunPushReceived`）。宿主需要在 `AndroidManifest.xml` 给该 Activity 配置对应厂商要求的 `intent-filter`（scheme / action），否则厂商通知点击可能打不开 App 或拿不到数据：

```xml
<activity
    android:name="com.margelo.nitro.alipush.ThirdPartMessageActivity"
    android:exported="true">
    <!-- 按各厂商文档填入 intent-filter -->
</activity>
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
// alias 默认 null，可省略：
await AliPush.bindTag(1, ['news', 'sports']);
await AliPush.unbindTag(1, ['news']);

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
| `initPush(appKey?, appSecret?)` | 注册设备、启动推送 | Android 必需，建议**在用户同意隐私后**调用；`appKey` / `appSecret` 都省略时走 manifest 配置。iOS 为无操作（在 AppDelegate 用 `setParams` 初始化）。框架加载由本库自动完成，不在本方法内 |

| `getDeviceId()` | 获取设备 `deviceId` | — |
| `bindAccount(account)` | 绑定账号 | — |
| `unbindAccount()` | 解绑账号 | — |
| `bindTag(target, tags, alias)` | 绑定标签 | `target`: 1 设备 / 2 账号 / 3 别名 |
| `unbindTag(target, tags, alias)` | 解绑标签 | 同上 |
| `listTags(target)` | 列出标签 | 返回 `string[]`（服务端逗号拼接，各端已拆分；无标签为 `[]`） |
| `addAlias(alias)` / `removeAlias(alias)` | 添加 / 移除别名 | — |
| `listAliases()` | 列出别名 | 返回 `string[]`（服务端逗号拼接，各端已拆分；无别名为 `[]`） |
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
