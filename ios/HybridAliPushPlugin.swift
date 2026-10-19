import Foundation
import UIKit
import UserNotifications
import CloudPushSDK
import NitroModules

/**
 * react-native-nitro-ali-push 的 iOS Nitro HybridObject（纯 Swift 实现）。
 *
 * 本类只负责与 JS 桥接（`CloudPushSDK` 同步方法、`AliPushEventBus` 事件订阅、
 * `getInitialMessage` 冷启动消息回放）。所有需要 NSObject 的关注点
 * —— `@objc` 暴露给 AppDelegate、`UNUserNotificationCenterDelegate`、
 * selector-based 通知观察者 —— 已由宿主工程的桥接类（参考本库历史 `ios/AliPushAppDelegate.swift`）承担。
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
      if let deviceId = CloudPushSDK.getDeviceId() {
        return deviceId
      } else {
        throw RuntimeError.error(withMessage: "getDeviceId() failed.")
      }
    }
  }

  func bindAccount(account: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.bindAccount(account, withCallback: { res in
          if res.success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  func unbindAccount() throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.unbindAccount({ res in
          if res.success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  func bindTag(target: Double, tags: [String], alias: Variant_NullType_String?) throws -> Promise<Void> {
    let aliasString: String? = alias?.asType(String.self)
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.bindTag(Int32(target), withTags: tags, withAlias: aliasString, withCallback: { res in
          if res.success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  func unbindTag(target: Double, tags: [String], alias: Variant_NullType_String?) throws -> Promise<Void> {
    let aliasString: String? = alias?.asType(String.self)
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.unbindTag(Int32(target), withTags: tags, withAlias: aliasString, withCallback: { res in
          if res.success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  func listTags(target: Double) throws -> Promise<[String]> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.listTags(Int32(target), withCallback: { res in
          if res.success {
            continuation.resume(returning: Self.splitCommaList(res.data as? String))
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  func addAlias(alias: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.addAlias(alias, withCallback: { res in
          if res.success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  func removeAlias(alias: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.removeAlias(alias, withCallback: { res in
          if res.success {
            continuation.resume()
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  func listAliases() throws -> Promise<[String]> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.listAliases({ res in
          if res.success {
            continuation.resume(returning: Self.splitCommaList(res.data as? String))
          } else {
            continuation.resume(throwing: RuntimeError.error(
              withMessage: res.error?.localizedDescription ?? "unknown error"))
          }
        })
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
      CloudPushSDK.syncBadgeNum(UInt(badge)) { _ in }
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
