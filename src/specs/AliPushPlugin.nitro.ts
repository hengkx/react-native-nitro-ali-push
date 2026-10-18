/**
 * 阿里云推送（react-native-nitro-ali-push）的 Nitro 原生接口规格。
 *
 * 本文件由 `nitrogen`（Nitro 代码生成器）读取，生成 C++ 桥接层以及 iOS Swift /
 * Android Kotlin 的实现桩。每个方法签名即为 JS 调用名（驼峰），与
 * {@link "../index"} 中的封装函数一一对应。
 *
 * 事件订阅采用 Nitro 的回调约定：`addListener` 接收一个 JS 回调，返回用于
 * 退订的 `() => void` 闭包（Nitro 会自动跨语言封送函数类型）。
 *
 * @packageDocumentation
 */
import { type HybridObject, type AnyMap } from 'react-native-nitro-modules';

import type { AliPushMessage } from '../types';

/**
 * 推送消息事件回调类型。
 *
 * 参数即 {@link AliPushMessage}，由原生端通过 {@link AliPushPlugin.addListener}
 * 注册的回调回传。
 */
export type AliPushListener = (message: AliPushMessage) => void;

/**
 * 阿里云推送原生模块（HybridObject）规格。
 *
 * - iOS 实现语言：`swift`（`HybridAliPushPlugin`）
 * - Android 实现语言：`kotlin`（`HybridAliPushPlugin`）
 *
 * @public
 */
export interface AliPushPlugin
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  /**
   * 初始化阿里云推送。
   *
   * - **Android**：通过 `appKey` / `appSecret` 向阿里云推送服务注册应用。
   * - **iOS**：初始化在原生 `AppDelegate` 中完成（见 README），此方法为无操作。
   */
  initPush(appKey: string, appSecret: string): Promise<void>;

  /** 获取设备唯一标识 `deviceId`。 */
  getDeviceId(): Promise<string>;

  /** 绑定账号。 */
  bindAccount(account: string): Promise<void>;

  /** 解绑账号。 */
  unbindAccount(): Promise<void>;

  /**
   * 绑定标签。
   *
   * @param target 目标类型（1 设备 / 2 账号 / 3 别名）。
   * @param tags 标签数组。
   * @param alias 别名（可空）。
   */
  bindTag(target: number, tags: string[], alias: string | null): Promise<void>;

  /**
   * 解绑标签。
   *
   * @param target 目标类型（1 设备 / 2 账号 / 3 别名）。
   * @param tags 标签数组。
   * @param alias 别名（可空）。
   */
  unbindTag(target: number, tags: string[], alias: string | null): Promise<void>;

  /** 列出当前标签（返回服务端响应字符串）。 */
  listTags(target: number): Promise<string>;

  /** 添加别名。 */
  addAlias(alias: string): Promise<void>;

  /** 移除别名。 */
  removeAlias(alias: string): Promise<void>;

  /** 列出当前别名（返回服务端响应字符串）。 */
  listAliases(): Promise<string>;

  /** 设置应用角标数字。 */
  setApplicationIconBadgeNumber(badge: number): Promise<void>;

  /** 获取应用当前角标数字。 */
  getApplicationIconBadgeNumber(): Promise<number>;

  /** 获取 App 冷启动（被通知唤起）时缓存的首条推送消息，无则 `null`。 */
  getInitialMessage(): Promise<AliPushMessage | null>;

  /** 获取 iOS 通知授权状态（Android 固定返回 `true`）。 */
  getAuthorizationStatus(): Promise<boolean>;

  /** 同步角标到阿里云服务端（仅 iOS 有效，Android 为无操作）。 */
  syncBadgeNum(badge: number): Promise<void>;

  /**
   * 订阅推送消息事件。
   *
   * @param listener 收到消息时的回调。
   * @returns 退订函数，调用即可取消该监听。
   */
  addListener(listener: AliPushListener): () => void;
}
