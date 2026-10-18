/**
 * 阿里云推送（react-native-nitro-ali-push）相关的 TypeScript 类型定义。
 *
 * 这些类型既用于描述 JS 端 API 的入参/返回值，也用于描述原生端通过
 * `aliyunPushReceived` 事件回传给 JS 的推送载荷结构。
 *
 * @packageDocumentation
 */
import { type AnyMap } from 'react-native-nitro-modules';

/**
 * 消息类型。
 *
 * - `'notification'` 通知栏消息；
 * - `'message'` 透传 / 非通知栏消息。
 *
 * 抽成命名类型，供 Nitro 代码生成器（nitrogen）识别（内联联合类型不被支持）。
 *
 * @public
 */
export type AliPushMessageType = 'notification' | 'message';

/**
 * 收到消息时 App 所处的状态。
 *
 * - `'active'` 前台运行中；
 * - `'inactive'` 非活跃（如来电打断）；
 * - `'background'` 后台。
 *
 * 抽成命名类型，供 Nitro 代码生成器识别。
 *
 * @public
 */
export type AliPushAppState = 'active' | 'inactive' | 'background';

/**
 * 推送载荷。
 *
 * 无论是「通知栏消息」(notification) 还是「透传/非通知栏消息」(message)，
 * 原生端通过 {@link ALI_PUSH_EVENT | `aliyunPushReceived`} 事件回传给 JS 的
 * 数据结构都遵循此接口。
 *
 * @public
 */
export interface AliPushMessage {
  /** 通知标题。 */
  title?: string;
  /** 通知副标题（iOS 在前台/点击场景下可能携带）。 */
  subtitle?: string;
  /** 通知正文 / 内容。 */
  body?: string;
  /** 角标数字。 */
  badge?: number;
  /**
   * 自定义键值对。
   *
   * 即推送后台设置的 `extras` / 业务参数，键为字符串，值可为字符串、数字、
   * 布尔或嵌套结构（经 Nitro 的 {@link AnyMap} 跨语言封送）。
   */
  extras?: AnyMap;
  /**
   * 消息类型：
   *
   * - `'notification'` 通知栏消息；
   * - `'message'` 透传 / 非通知栏消息。
   */
  type?: AliPushMessageType;
  /**
   * 点击行为标识：
   *
   * - `'opened'` 用户点击打开；
   * - `'removed'` 用户删除；
   * - 其它字符串表示自定义 action 标识。
   */
  actionIdentifier?: string;
  /**
   * 收到消息时 App 所处的状态：
   *
   * - `'active'` 前台运行中；
   * - `'inactive'` 非活跃（如来电打断）；
   * - `'background'` 后台。
   */
  appState?: AliPushAppState;
  /** 通知到达 / 点击的时间。iOS 为 `Date` 序列化后的值（数字时间戳或字符串）。 */
  date?: number | string;
}

/**
 * 本库支持监听的事件名。
 *
 * 目前仅支持 {@link ALI_PUSH_EVENT}。
 *
 * @public
 */
export type AliPushEvent = typeof ALI_PUSH_EVENT;

/**
 * 推送消息事件名常量。
 *
 * 通过 {@link addEventListener} 订阅，回调参数为 {@link AliPushMessage}。
 *
 * @public
 */
export const ALI_PUSH_EVENT = 'aliyunPushReceived' as const;

/**
 * 绑定 / 解绑标签时的目标类型。
 *
 * 对应阿里云推送 SDK 的 `target` 参数：
 *
 * - `1` 针对设备；
 * - `2` 针对账号；
 * - `3` 针对别名。
 *
 * @public
 */
export type AliPushTagTarget = 1 | 2 | 3;
