import Foundation
import UIKit
import UserNotifications
import CloudPushSDK
import NitroModules

/// 通知栏消息类型。
private let ALIYUN_PUSH_TYPE_NOTIFICATION = "notification"
/// 透传 / 非通知栏消息类型。
private let ALIYUN_PUSH_TYPE_MESSAGE = "message"

/// Debug 下输出日志（对应原 Objective-C 的 `DLog` 宏）。
private func DLog(_ message: String, file: String = #file, line: UInt = #line) {
  #if DEBUG
  print("<\((file as NSString).lastPathComponent):\(line)> \(message)")
  #endif
}

/**
 * react-native-nitro-ali-push 的 iOS 原生实现（Swift，Nitro HybridObject）。
 *
 * 通过 `nitrogen` 生成的 `HybridAliPushPluginSpec` 协议暴露给 JS；初始化、APNs 注册、
 * `CloudPushSDK` 回调以及事件分发都在本类完成。
 *
 * iOS 端的推送初始化必须在原生层完成（AppDelegate 调用 `shared.setParams`），而不是
 * 从 JS 调用 `initPush`（该方法在 iOS 上为无操作）。
 */
/// 必须 `public`：本库作为 pod 是独立模块，App 的 Swift/ObjC 需要引用它。
/// 仅 `internal` 时不会写进 `<react_native_nitro_ali_push-Swift.h>`，App 端编译报
/// "Use of undeclared identifier 'HybridAliPushPlugin'"。`@objc` 运行时名保持不变。
@objc(HybridAliPushPlugin)
public final class HybridAliPushPlugin: HybridAliPushPluginSpec, UNUserNotificationCenterDelegate {
  /// 由 AppDelegate 创建的权威实例（持有 UNUserNotificationCenter 代理与 CloudPushSDK 回调）。
  private static var sharedInstance: HybridAliPushPlugin?
  /// JS 注册的监听器（静态池，AppDelegate 实例与 JS 实例共享）。
  private static var listeners: [UUID: (AliPushMessage) -> Void] = [:]
  /// App 冷启动（被通知唤起）时、JS 尚未完成订阅的窗口期内到达的首条消息缓存。
  private static var initialNotification: AliPushMessage?

  // MARK: - 单例（供 AppDelegate 使用）

  @objc public static func shared() -> HybridAliPushPlugin {
    if let instance = sharedInstance { return instance }
    let instance = HybridAliPushPlugin()
    sharedInstance = instance
    return instance
  }

  // MARK: - 生命周期 / Nitro 必填

  override init() {
    super.init()
  }

  // MARK: - 由原生 AppDelegate 调用完成 iOS 端推送初始化（不应从 JS 调用）

  @objc public func setParams(_ appKey: String,
                       appSecret: String,
                       lauchOptions: [AnyHashable: Any]?,
                       createNotificationCategoryHandler: @escaping () -> Void) {
    registerAPNs(createNotificationCategoryHandler)
    initCloudPush(appKey: appKey, appSecret: appSecret)
    listenerOnChannelOpened()
    registerMessageReceive()
    CloudPushSDK.sendNotificationAck(lauchOptions)
  }

  // MARK: - APNs 注册

  private func registerAPNs(_ createNotificationCategoryHandler: (() -> Void)?) {
    let center = UNUserNotificationCenter.current()
    createNotificationCategoryHandler?()
    center.delegate = self

    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if granted {
        DLog("User authorized notification.")
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      } else {
        DLog("User denied notification: \(String(describing: error))")
      }
    }
  }

  // MARK: - SDK 初始化

  private func initCloudPush(appKey: String, appSecret: String) {
    CloudPushSDK.start(withAppkey: appKey, appSecret: appSecret) { res in
      if res?.success ?? false {
        DLog("Push SDK init success, deviceId: \(String(describing: CloudPushSDK.getDeviceId())).")
      } else {
        DLog("Push SDK init failed, error: \(String(describing: res?.error)).")
      }
    }
  }

  // MARK: - AppDelegate 转发方法

  @objc public func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    CloudPushSDK.registerDevice(deviceToken) { res in
      if res?.success ?? false {
        DLog("Register deviceToken success.")
      } else {
        DLog("Register deviceToken failed, error: \(String(describing: res?.error)).")
      }
    }
  }

  @objc public func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    DLog("Get deviceToken failed, error: \(error.localizedDescription)")
  }

  @objc public func application(_ application: UIApplication,
                          didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                          fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    CloudPushSDK.sendNotificationAck(userInfo)
    completionHandler(.newData)
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// App 处于前台时收到通知。
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    DLog("Receive a notification in foreground.")
    let content = notification.request.content
    let userInfo = content.userInfo

    var dict: [AnyHashable: Any] = [:]
    dict["date"] = notification.date
    dict["title"] = content.title
    dict["subtitle"] = content.subtitle
    if let body = content.body as String? { dict["body"] = body }
    if let badge = content.badge as? NSNumber { dict["badge"] = badge }
    UIApplication.shared.applicationIconBadgeNumber = content.badge?.intValue ?? 0
    dict["extras"] = userInfo
    dict["type"] = ALIYUN_PUSH_TYPE_NOTIFICATION

    sendEventToJs(buildMessage(dict))
    CloudPushSDK.sendNotificationAck(userInfo)

    completionHandler(content.body.isEmpty ? [] : [.sound, .alert, .badge])
  }

  /// 用户点击 / 删除 / 自定义 action 回调。
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    DLog("Open/delete a notification.")
    let content = response.notification.request.content
    let userInfo = content.userInfo

    var dict: [AnyHashable: Any] = [:]
    dict["date"] = response.notification.date
    dict["title"] = content.title
    dict["subtitle"] = content.subtitle
    if let body = content.body as String? { dict["body"] = body }
    if let badge = content.badge as? NSNumber { dict["badge"] = badge }
    UIApplication.shared.applicationIconBadgeNumber = content.badge?.intValue ?? 0
    dict["extras"] = userInfo
    dict["type"] = ALIYUN_PUSH_TYPE_NOTIFICATION

    if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      dict["actionIdentifier"] = "opened"
    } else if response.actionIdentifier == UNNotificationDismissActionIdentifier {
      dict["actionIdentifier"] = "removed"
    } else {
      dict["actionIdentifier"] = response.actionIdentifier
    }

    sendEventToJs(buildMessage(dict))
    CloudPushSDK.sendNotificationAck(userInfo)
    completionHandler()
  }

  // MARK: - 通道 / 消息监听

  private func listenerOnChannelOpened() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onChannelOpened(_:)),
      name: NSNotification.Name("CCPDidChannelConnectedSuccess"),
      object: nil
    )
  }

  @objc private func onChannelOpened(_ notification: Notification) {
    DLog("ChannelOpened.")
  }

  private func registerMessageReceive() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onMessageReceived(_:)),
      name: NSNotification.Name("CCPDidReceiveMessageNotification"),
      object: nil
    )
  }

  @objc private func onMessageReceived(_ notification: Notification) {
    DLog("onMessageReceived.")
    let data = (notification.object as? [AnyHashable: Any]) ?? [:]

    var dict: [AnyHashable: Any] = [:]
    if let title = data["title"] { dict["title"] = title }
    if let body = data["body"] { dict["body"] = body }
    dict["extras"] = notification.userInfo ?? [:]
    dict["type"] = ALIYUN_PUSH_TYPE_MESSAGE

    sendEventToJs(buildMessage(dict))
  }

  // MARK: - 发送事件

  /// 把原生字典组装为 `AliPushMessage` 并分发给 JS 监听器（或缓存首条冷启动消息）。
  private func sendEventToJs(_ message: AliPushMessage) {
    DLog("sendEventToJs:")
    var payload = message
    payload = withAppState(payload)

    if HybridAliPushPlugin.listeners.isEmpty {
      if HybridAliPushPlugin.initialNotification == nil {
        HybridAliPushPlugin.initialNotification = payload
      }
      return
    }
    for listener in HybridAliPushPlugin.listeners.values {
      listener(payload)
    }
  }

  private func withAppState(_ message: AliPushMessage) -> AliPushMessage {
    let state: AliPushAppState
    switch UIApplication.shared.applicationState {
    case .active: state = .active
    case .inactive: state = .inactive
    case .background: state = .background
    @unknown default: return message
    }
    return AliPushMessage(
      title: message.title,
      subtitle: message.subtitle,
      body: message.body,
      badge: message.badge,
      extras: message.extras,
      type: message.type,
      actionIdentifier: message.actionIdentifier,
      appState: state,
      date: message.date
    )
  }

  /// 由 `[AnyHashable: Any]` 组装 `AliPushMessage`。
  private func buildMessage(_ dict: [AnyHashable: Any]) -> AliPushMessage {
    let title = dict["title"] as? String
    let subtitle = dict["subtitle"] as? String
    let body = dict["body"] as? String
    let badge = (dict["badge"] as? NSNumber)?.doubleValue

    var type: AliPushMessageType?
    if let rawType = dict["type"] as? String, let t = AliPushMessageType(fromString: rawType) {
      type = t
    }
    let actionIdentifier = dict["actionIdentifier"] as? String

    var appState: AliPushAppState?
    if let rawState = dict["appState"] as? String, let s = AliPushAppState(fromString: rawState) {
      appState = s
    }

    let extras: AnyMap?
    if let rawExtras = dict["extras"] as? [AnyHashable: Any] {
      var safe: [String: Any?] = [:]
      for (k, v) in rawExtras {
        if let key = k as? String {
          safe[key] = v
        }
      }
      extras = (try? AnyMap.fromDictionaryIgnoreIncompatible(safe)) ?? nil
    } else {
      extras = nil
    }

    let date: Variant_Double_String?
    if let rawDate = dict["date"] as? Date {
      date = .first(rawDate.timeIntervalSince1970)
    } else if let rawDate = dict["date"] as? String {
      date = .second(rawDate)
    } else if let rawDate = dict["date"] as? NSNumber {
      date = .first(rawDate.doubleValue)
    } else {
      date = nil
    }

    return AliPushMessage(
      title: title,
      subtitle: subtitle,
      body: body,
      badge: badge,
      extras: extras,
      type: type,
      actionIdentifier: actionIdentifier,
      appState: appState,
      date: date
    )
  }

  // MARK: - 暴露给 JS 的方法

  public func initPush(appKey: String, appSecret: String) throws -> Promise<Void> {
    // iOS 端初始化在 AppDelegate 中完成，这里直接成功。
    return Promise.resolved()
  }

  public func getDeviceId() throws -> Promise<String> {
    return Promise.async {
      if let deviceId = CloudPushSDK.getDeviceId() {
        return deviceId
      } else {
        throw RuntimeError.error(withMessage: "getDeviceId() failed.")
      }
    }
  }

  public func bindAccount(account: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.bindAccount(account, withCallback: { res in
          if let res = res, res.success {
            continuation.resume()
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func unbindAccount() throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.unbindAccount(withCallback: { res in
          if let res = res, res.success {
            continuation.resume()
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func bindTag(target: Double, tags: [String], alias: Variant_NullType_String?) throws -> Promise<Void> {
    let aliasString: String?
    if case .second(let s) = alias {
      aliasString = s
    } else {
      aliasString = nil
    }
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.bindTag(Int(target), withTags: tags, withAlias: aliasString, withCallback: { res in
          if let res = res, res.success {
            continuation.resume()
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func unbindTag(target: Double, tags: [String], alias: Variant_NullType_String?) throws -> Promise<Void> {
    let aliasString: String?
    if case .second(let s) = alias {
      aliasString = s
    } else {
      aliasString = nil
    }
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.unbindTag(Int(target), withTags: tags, withAlias: aliasString, withCallback: { res in
          if let res = res, res.success {
            continuation.resume()
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func listTags(target: Double) throws -> Promise<String> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.listTags(Int(target), withCallback: { res in
          if let res = res, res.success {
            continuation.resume(returning: res.data as? String ?? "")
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func addAlias(alias: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.addAlias(alias, withCallback: { res in
          if let res = res, res.success {
            continuation.resume()
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func removeAlias(alias: String) throws -> Promise<Void> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.removeAlias(alias, withCallback: { res in
          if let res = res, res.success {
            continuation.resume()
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func listAliases() throws -> Promise<String> {
    return Promise.async {
      try await withCheckedThrowingContinuation { continuation in
        CloudPushSDK.listAliases(withCallback: { res in
          if let res = res, res.success {
            continuation.resume(returning: res.data as? String ?? "")
          } else {
            let err = res?.error
            continuation.resume(throwing: RuntimeError.error(
              withMessage: err?.localizedDescription ?? "unknown error"))
          }
        })
      }
    }
  }

  public func setApplicationIconBadgeNumber(badge: Double) throws -> Promise<Void> {
    return Promise.async {
      UIApplication.shared.applicationIconBadgeNumber = Int(badge)
    }
  }

  public func getApplicationIconBadgeNumber() throws -> Promise<Double> {
    return Promise.resolved(withResult: Double(UIApplication.shared.applicationIconBadgeNumber))
  }

  public func getInitialMessage() throws -> Promise<Variant_NullType_AliPushMessage> {
    if let cached = HybridAliPushPlugin.initialNotification {
      HybridAliPushPlugin.initialNotification = nil
      return Promise.resolved(withResult: .second(cached))
    }
    return Promise.resolved(withResult: .first(NullType.null))
  }

  public func getAuthorizationStatus() throws -> Promise<Bool> {
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

  public func syncBadgeNum(badge: Double) throws -> Promise<Void> {
    return Promise.async {
      CloudPushSDK.syncBadgeNum(Int(badge))
    }
  }

  public func addListener(listener: @escaping (AliPushMessage) -> Void) throws -> () -> Void {
    let id = UUID()
    HybridAliPushPlugin.listeners[id] = listener
    if let cached = HybridAliPushPlugin.initialNotification {
      HybridAliPushPlugin.initialNotification = nil
      listener(cached)
    }
    return {
      HybridAliPushPlugin.listeners.removeValue(forKey: id)
    }
  }
}
