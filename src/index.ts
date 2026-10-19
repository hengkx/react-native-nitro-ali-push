/**
 * react-native-nitro-ali-push —— 阿里云移动推送 React Native 封装（Nitro Modules）。
 *
 * 提供账号 / 标签 / 别名绑定、设备号获取、角标管理，以及统一的推送消息事件订阅。
 * 原生实现基于 Nitro Modules（HybridObject），iOS 端为 Swift、Android 端为 Kotlin，
 * 由 `nitrogen` 代码生成器生成桥接层。
 *
 * @packageDocumentation
 */
import { NitroModules } from 'react-native-nitro-modules';

import type { AliPushPlugin } from './specs/AliPushPlugin.nitro';
import { ALI_PUSH_EVENT } from './types';
import type { AliPushEvent, AliPushMessage, AliPushTagTarget } from './types';

/**
 * 原生模块实例（Nitro HybridObject）。
 *
 * 若宿主工程未正确集成 Nitro 或缺少原生实现，会在此处抛错。
 *
 * @internal
 */
const AliPushNative = NitroModules.createHybridObject<AliPushPlugin>('AliPushPlugin');

/**
 * 向阿里云推送服务注册应用（启动推送逻辑）。
 *
 * @remarks
 * **Android**：调用 SDK 的 `register(...)` 完成设备注册，这是真正开始推送、并采集
 * 设备标识的一步，因此**请在获得用户隐私授权后再调用**。
 *
 * SDK 框架的加载（`PushServiceFactory.init`，按官方「2.1 初始化」要求须在
 * `Application.onCreate` 之前完成）由本库的 `AliPushInitProvider` 自动完成，
 * **无需宿主写任何原生代码**，且该阶段不采集隐私。
 *
 * @param appKey - 阿里云推送控制台分配的 AppKey。省略则走 manifest 配置方式。
 * @param appSecret - 阿里云推送控制台分配的 AppSecret。省略则走 manifest 配置方式。
 * @returns 注册完成的 Promise。
 *
 * @example
 * ```ts
 * // 代码方式
 * await AliPush.initPush('your_app_key', 'your_app_secret');
 *
 * // manifest 方式（AndroidManifest.xml 已配 appkey/appsecret）
 * await AliPush.initPush();
 * ```
 */
export function initPush(appKey?: string, appSecret?: string): Promise<void> {
  return AliPushNative.initPush(appKey, appSecret);
}

/**
 * 获取设备唯一标识 `deviceId`。
 *
 * @returns 解析为设备 `deviceId` 字符串的 Promise。
 *
 * @example
 * ```ts
 * const deviceId = await AliPush.getDeviceId();
 * console.log(deviceId);
 * ```
 */
export function getDeviceId(): Promise<string> {
  return AliPushNative.getDeviceId();
}

/**
 * 绑定账号。
 *
 * @param account - 待绑定的账号（字符串，长度建议 ≤ 64）。
 * @returns 操作完成的 Promise。
 */
export function bindAccount(account: string): Promise<void> {
  return AliPushNative.bindAccount(account);
}

/**
 * 解绑账号（解绑当前已绑定账号）。
 *
 * @returns 操作完成的 Promise。
 */
export function unbindAccount(): Promise<void> {
  return AliPushNative.unbindAccount();
}

/**
 * 绑定标签。
 *
 * @param target - 目标类型：`1` 设备 / `2` 账号 / `3` 别名。
 * @param tags - 标签数组（字符串）。
 * @param alias - 别名（可空，仅 `target = 3` 时生效）。
 * @returns 操作完成的 Promise。
 *
 * @example
 * ```ts
 * await AliPush.bindTag(1, ['news', 'sports'], null);
 * ```
 */
export function bindTag(
  target: AliPushTagTarget,
  tags: string[],
  alias: string | null = null,
): Promise<void> {
  return AliPushNative.bindTag(target, tags, alias);
}

/**
 * 解绑标签。参数语义同 {@link bindTag}。
 *
 * @param target - 目标类型：`1` 设备 / `2` 账号 / `3` 别名。
 * @param tags - 待解绑的标签数组。
 * @param alias - 别名（可空）。
 * @returns 操作完成的 Promise。
 */
export function unbindTag(
  target: AliPushTagTarget,
  tags: string[],
  alias: string | null = null,
): Promise<void> {
  return AliPushNative.unbindTag(target, tags, alias);
}

/**
 * 列出当前已绑定的标签。
 *
 * @param target - 目标类型：`1` 设备 / `2` 账号 / `3` 别名。
 * @returns 解析为标签字符串数组的 Promise（服务端以逗号拼接，各端已拆分；无标签时为空数组）。
 */
export function listTags(target: AliPushTagTarget): Promise<string[]> {
  return AliPushNative.listTags(target);
}

/**
 * 添加别名。
 *
 * @param alias - 待添加的别名。
 * @returns 操作完成的 Promise。
 */
export function addAlias(alias: string): Promise<void> {
  return AliPushNative.addAlias(alias);
}

/**
 * 移除别名。
 *
 * @param alias - 待移除的别名。
 * @returns 操作完成的 Promise。
 */
export function removeAlias(alias: string): Promise<void> {
  return AliPushNative.removeAlias(alias);
}

/**
 * 列出当前已添加的别名。
 *
 * @returns 解析为别名字符串数组的 Promise（服务端以逗号拼接，各端已拆分；无别名为空数组）。
 */
export function listAliases(): Promise<string[]> {
  return AliPushNative.listAliases();
}

/**
 * 设置应用角标（桌面图标右上角数字）。
 *
 * @param badge - 角标数字，`0` 表示清除。
 * @returns 操作完成的 Promise。
 */
export function setApplicationIconBadgeNumber(badge: number): Promise<void> {
  return AliPushNative.setApplicationIconBadgeNumber(badge);
}

/**
 * 获取应用当前角标数字。
 *
 * @returns 解析为当前角标数字的 Promise。
 */
export function getApplicationIconBadgeNumber(): Promise<number> {
  return AliPushNative.getApplicationIconBadgeNumber();
}

/**
 * 获取 App 冷启动（被通知唤起）时缓存的首条推送消息。
 *
 * @remarks
 * 当 App 完全退出后被通知点击唤起，JS 尚未完成订阅的窗口期内到达的消息会被原生端
 * 缓存，待 JS 就绪后通过此方法或 {@link ALI_PUSH_EVENT} 事件返回。
 *
 * @returns 缓存消息对象，无则 `null`。
 */
export function getInitialMessage(): Promise<AliPushMessage | null> {
  return AliPushNative.getInitialMessage();
}

/**
 * 获取 iOS 通知授权状态。
 *
 * @remarks Android 平台固定返回 `true`（Android 不做通知权限前置拦截）。
 *
 * @returns 解析为是否已授权的布尔值 Promise。
 */
export function getAuthorizationStatus(): Promise<boolean> {
  return AliPushNative.getAuthorizationStatus();
}

/**
 * 将角标数字同步到阿里云服务端。
 *
 * @remarks 仅 iOS 有效，Android 为无操作。
 *
 * @param badge - 角标数字。
 * @returns 操作完成的 Promise。
 */
export function syncBadgeNum(badge: number): Promise<void> {
  return AliPushNative.syncBadgeNum(badge);
}

/**
 * 订阅推送消息事件。
 *
 * @param event - 事件名，本库仅支持 {@link ALI_PUSH_EVENT}（`'aliyunPushReceived'`）。
 * @param listener - 回调，参数为 {@link AliPushMessage}。
 * @returns 退订函数，调用即可取消该监听。
 *
 * @example
 * ```ts
 * const unsubscribe = AliPush.addEventListener('aliyunPushReceived', (msg) => {
 *   console.log('收到推送', msg.title, msg.body);
 * });
 * // 不再需要时
 * unsubscribe();
 * ```
 */
export function addEventListener(
  event: AliPushEvent,
  listener: (message: AliPushMessage) => void,
): () => void {
  if (event !== ALI_PUSH_EVENT) {
    console.warn(`[react-native-nitro-ali-push] Unsupported event: ${event}`);
    return () => {};
  }
  return AliPushNative.addListener(listener);
}

/**
 * 取消订阅推送消息事件。
 *
 * @param unsubscribe - {@link addEventListener} 返回的退订函数。
 *
 * @example
 * ```ts
 * AliPush.removeEventListener(unsubscribe);
 * ```
 */
export function removeEventListener(unsubscribe: () => void): void {
  unsubscribe?.();
}

/**
 * 默认导出对象（同时支持具名与默认导入）。
 *
 * @public
 */
const AliPush = {
  initPush,
  getDeviceId,
  bindAccount,
  unbindAccount,
  bindTag,
  unbindTag,
  listTags,
  addAlias,
  removeAlias,
  listAliases,
  setApplicationIconBadgeNumber,
  getApplicationIconBadgeNumber,
  getInitialMessage,
  getAuthorizationStatus,
  syncBadgeNum,
  addEventListener,
  removeEventListener,
  /** 事件名常量，便于 `addEventListener(AliPush.ALI_PUSH_EVENT, ...)`。 */
  ALI_PUSH_EVENT,
};

export { ALI_PUSH_EVENT };
export type { AliPushEvent, AliPushMessage, AliPushTagTarget };
export default AliPush;
