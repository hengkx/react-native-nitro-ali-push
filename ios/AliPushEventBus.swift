import Foundation

/// 推送消息的进程内事件总线。
///
/// 桥接类（`AliPushAppDelegate`，**位于宿主工程，不在本库**）负责从 `UNUserNotificationCenter` 与
/// `NSNotificationCenter` 接收原生事件并 `emit`；Nitro 的 HybridObject
///（`HybridAliPushPlugin`）在 JS 调 `addListener` 时从总线 `subscribe`。
///
/// 本类声明为 `public`：宿主的 `AliPushAppDelegate` 与库的 `HybridAliPushPlugin` 分属两个不同的
/// Swift module，internal 符号跨 module 不可见，故总线作为两者唯一的跨 module 通道必须公开。
///
/// 总线仅承载「从原生 → JS」的单向事件，不需要回调到原生。冷启动（JS 尚未订阅就
/// 已收到）消息由 `pendingInitial` 缓存，首个订阅者会立刻取走。
public enum AliPushEventBus {
  private static var listeners: [UUID: (AliPushMessage) -> Void] = [:]
  private static var pendingInitial: AliPushMessage?

  /// 订阅事件。返回的闭包调用后取消订阅。
  ///
  /// 若冷启动期间已有缓存消息，首个订阅者会立刻收到（并清空缓存），
  /// 与 `takePendingInitial()` 共用同一个槽位——谁先调用谁取走。
  @discardableResult
  public static func subscribe(_ cb: @escaping (AliPushMessage) -> Void) -> () -> Void {
    let id = UUID()
    listeners[id] = cb
    if let cached = takePendingInitial() {
      cb(cached)
    }
    return {
      listeners.removeValue(forKey: id)
    }
  }

  /// 由桥接类 / 原生层投递一条消息。
  public static func emit(_ message: AliPushMessage) {
    if listeners.isEmpty {
      if pendingInitial == nil { pendingInitial = message }
      return
    }
    for cb in listeners.values { cb(message) }
  }

  /// 取走并清空冷启动缓存消息（供 `getInitialMessage` 使用）。无缓存返回 `nil`。
  public static func takePendingInitial() -> AliPushMessage? {
    defer { pendingInitial = nil }
    return pendingInitial
  }

  /// 测试 / 调试使用：清空全部状态。
  public static func reset() {
    listeners.removeAll()
    pendingInitial = nil
  }
}
