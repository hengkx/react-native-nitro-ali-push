import Foundation
import UIKit
import UserNotifications
import CloudPushSDK
import NitroModules

/// iOS 端的 AppDelegate 集成桥。
///
/// 把所有需要 NSObject 的关注点（`@objc` 单例、APNs 代理、`UNUserNotificationCenterDelegate`、
/// selector-based `NSNotificationCenter` 观察者）集中在这里，避免污染 Nitro 生成的
/// `HybridAliPushPlugin` 继承链 —— 那个基类不是 NSObject，硬撑会引入"每次 codegen
/// 都要重打补丁"的维护负担。
///
/// 与 JS 的事件分发通过 `AliPushEventBus` 解耦：本类只负责「原生事件 → bus.emit」，
/// Nitro HybridObject 负责「bus → JS 监听器」，彼此单向。
@objc(AliPushAppDelegate)
public final class AliPushAppDelegate: NSObject, UNUserNotificationCenterDelegate {
  private static var sharedInstance: AliPushAppDelegate?

  /// 共享单例。`@objc` 让 ObjC 端可通过 `[AliPushAppDelegate shared]` 调用。
  @objc public static func shared() -> AliPushAppDelegate {
    if let instance = sharedInstance { return instance }
    let instance = AliPushAppDelegate()
    sharedInstance = instance
    return instance
  }

  // MARK: - 生命周期

  private override init() {
    super.init()
    observeChannelOpened()
    observeMessageReceived()
  }

  // MARK: - 由宿主 AppDelegate 调用完成 iOS 端推送初始化

  /// 初始化阿里云推送。**不要从 JS 调用。**
  ///
  /// 典型用法：
  /// ```swift
  /// AliPushAppDelegate.shared().setParams(
  ///   "<appKey>", appSecret: "<appSecret>",
  ///   lauchOptions: launchOptions,
  ///   createNotificationCategoryHandler: { }
  /// )
  /// ```
  @objc public func setParams(
    _ appKey: String,
    appSecret: String,
    lauchOptions: [AnyHashable: Any]?,
    createNotificationCategoryHandler: @escaping () -> Void
  ) {
    registerAPNs(createNotificationCategoryHandler)
    initCloudPush(appKey: appKey, appSecret: appSecret)
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

  @objc public func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    CloudPushSDK.registerDevice(deviceToken) { res in
      if res?.success ?? false {
        DLog("Register deviceToken success.")
      } else {
        DLog("Register deviceToken failed, error: \(String(describing: res?.error)).")
      }
    }
  }

  @objc public func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    DLog("Get deviceToken failed, error: \(error.localizedDescription)")
  }

  @objc public func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    CloudPushSDK.sendNotificationAck(userInfo)
    completionHandler(.newData)
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// App 处于前台时收到通知。
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
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

    AliPushEventBus.emit(buildMessage(dict))
    CloudPushSDK.sendNotificationAck(userInfo)

    completionHandler(content.body.isEmpty ? [] : [.sound, .alert, .badge])
  }

  /// 用户点击 / 删除 / 自定义 action 回调。
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
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

    AliPushEventBus.emit(buildMessage(dict))
    CloudPushSDK.sendNotificationAck(userInfo)
    completionHandler()
  }

  // MARK: - 通道 / 消息监听（NSObject-based 通知）

  private func observeChannelOpened() {
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

  private func observeMessageReceived() {
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

    AliPushEventBus.emit(buildMessage(dict))
  }

  // MARK: - 消息组装（与之前完全一致）

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
        if let key = k as? String { safe[key] = v }
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

    // 补 appState
    let finalAppState: AliPushAppState = appState ?? {
      switch UIApplication.shared.applicationState {
      case .active: return .active
      case .inactive: return .inactive
      case .background: return .background
      @unknown default: return .background
      }
    }()

    return AliPushMessage(
      title: title,
      subtitle: subtitle,
      body: body,
      badge: badge,
      extras: extras,
      type: type,
      actionIdentifier: actionIdentifier,
      appState: finalAppState,
      date: date
    )
  }
}
