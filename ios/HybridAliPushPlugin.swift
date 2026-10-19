import Foundation
import UIKit
import UserNotifications
import NitroModules

/**
 * react-native-nitro-ali-push 的 iOS Nitro HybridObject（纯 Swift 实现）。
 *
 * 本类只负责与 JS 桥接（`AliPushSDKProxy` 事件订阅、
 * `getInitialMessage` 冷启动消息回放）。所有需要 NSObject 的关注点
 * —— `@objc` 暴露给 AppDelegate、`UNUserNotificationCenterDelegate`、
 * selector-based 通知观察者 —— 已由宿主工程的桥接类（参考本库历史 `ios/AliPushAppDelegate.swift`）承担。
 *
 * **关于阿里云 SDK 隔离**：本 Swift 文件**永不 `import CloudPushSDK`**。所有 CloudPushSDK
 * 的调用都收敛在 `AliPushSDKProxy.mm`（ObjC++ 编译单元）中，本类只通过同 module 的轻量
 * `@objc` 协议 `AliPushSDKProxying` 与之通信。这样可以阻断 CloudPushSDK 内部 libc++ 头
 * （`cstddef` 等）与 framework 的 non-modular header 被 Swift 的编译上下文加载——
 * 否则 Nitro 的 C++ 互操作子编译会报 `cstddef file not found`。
 *
 * iOS 端的推送初始化必须在原生层完成（AppDelegate 调用
 * `AliPushAppDelegate.shared().setParams(...)`）。
 */
final class HybridAliPushPlugin: HybridAliPushPluginSpec {
  // MARK: - 暴露给 JS 的方法

  func registerPush() throws -> Promise<Void> {
    // iOS 端初始化与注册都在 AppDelegate 中通过 AliPushAppDelegate.setParams 完成。
    return Promise.resolved()
  }

  func getDeviceId() throws -> Promise<String> {
    return Promise.async {
      if let deviceId = AliPushSDKProxy.shared().getDeviceId() {
        return deviceId
      } else {
        throw RuntimeError.error(withMessage: "getDeviceId() failed.")
      }
    }
  }

  func bindAccount(account: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().bindAccount(account) { success, error in
          if success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func unbindAccount() throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().unbindAccount { success, error in
          if success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func bindTag(target: Double, tags: [String], alias: Variant_NullType_String?) throws -> Promise<Void> {
    let aliasString: String? = alias?.asType(String.self)
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().bindTag(Int32(target), tags: tags, alias: aliasString) { success, error in
          if success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func unbindTag(target: Double, tags: [String], alias: Variant_NullType_String?) throws -> Promise<Void> {
    let aliasString: String? = alias?.asType(String.self)
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().unbindTag(Int32(target), tags: tags, alias: aliasString) { success, error in
          if success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func listTags(target: Double) throws -> Promise<[String]> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().listTags(Int32(target)) { success, error, data in
          if success {
            continuation.resume(returning: Self.splitCommaList(data))
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func addAlias(alias: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().addAlias(alias) { success, error in
          if success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func removeAlias(alias: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().removeAlias(alias) { success, error in
          if success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func listAliases() throws -> Promise<[String]> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        AliPushSDKProxy.shared().listAliases { success, error, data in
          if success {
            continuation.resume(returning: Self.splitCommaList(data))
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: error ?? "unknown error"))
          }
        }
      }
    }
  }

  func setApplicationIconBadgeNumber(badge: Double) throws -> Promise<Void> {
    return Promise.async {
      UIApplication.shared.applicationIconBadgeNumber = Int(badge)
    }
  }

  func getApplicationIconBadgeNumber() throws -> Promise<Double> {
    return Promise.resolved(withResult: Double(UIApplication.shared.applicationIconBadgeNumber))
  }

  func getInitialMessage() throws -> Promise<Variant_NullType_AliPushMessage> {
    // 冷启动回放：与 addListener 共用同一个 pending 槽位，谁先调用谁取走。
    if let cached = AliPushEventBus.takePendingInitial() {
      return Promise.resolved(withResult: .second(cached))
    }
    return Promise.resolved(withResult: .first(NullType.null))
  }

  func getAuthorizationStatus() throws -> Promise<Bool> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            continuation.resume(returning: settings.authorizationStatus == .authorized)
          }
        } else {
          continuation.resume(returning: true)
        }
      }
    }
  }

  func syncBadgeNum(badge: Double) throws -> Promise<Void> {
    return Promise.async {
      AliPushSDKProxy.shared().syncBadgeNum(UInt(badge)) { _, _ in }
    }
  }

  func addListener(listener: @escaping (AliPushMessage) -> Void) throws -> () -> Void {
    return AliPushEventBus.subscribe(listener)
  }

  // MARK: - 私有

  /// 服务端以逗号拼接返回标签 / 别名，统一拆分为数组（去空白、丢空项）。
  private static func splitCommaList(_ raw: String?) -> [String] {
    guard let raw = raw, !raw.isEmpty else { return [] }
    return raw
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}
