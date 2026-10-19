import Foundation

/// Debug 下输出日志（对应原 Objective-C 的 `DLog` 宏）。
public func DLog(_ message: String, file: String = #file, line: UInt = #line) {
  #if DEBUG
  print("<\((file as NSString).lastPathComponent):\(line)> \(message)")
  #endif
}

/// 通知栏消息类型。
public let ALIYUN_PUSH_TYPE_NOTIFICATION = "notification"
/// 透传 / 非通知栏消息类型。
public let ALIYUN_PUSH_TYPE_MESSAGE = "message"
