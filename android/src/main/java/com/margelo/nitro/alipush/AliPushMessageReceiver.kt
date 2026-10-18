package com.margelo.nitro.alipush

import android.content.Context
import android.os.Bundle
import android.util.Log
import com.alibaba.sdk.android.push.MessageReceiver
import com.alibaba.sdk.android.push.notification.CPushMessage
import com.margelo.nitro.core.AnyMap

/**
 * 阿里云推送广播接收器。
 *
 * 在 `AndroidManifest.xml` 中静态注册（见同目录 `AndroidManifest.xml`）。收到通知 /
 * 消息 / 通知打开 / 通知删除等回调时，把数据组装成 [AliPushMessage] 并通过
 * [HybridAliPushPlugin.dispatch] 发往 JS 的 `aliyunPushReceived` 事件；同时把「App 未
 * 运行被通知唤起」场景下的首条消息缓存到 [HybridAliPushPlugin]（由 `getInitialMessage`
 * 读取后清空）。
 */
class AliPushMessageReceiver : MessageReceiver() {

  override fun onNotification(
    context: Context?,
    title: String?,
    summary: String?,
    extraMap: Map<String, String>?,
  ) {
    val message = AliPushMessage(
      title = title,
      subtitle = null,
      body = summary,
      badge = null,
      extras = buildExtras(extraMap),
      type = AliPushMessageType.NOTIFICATION,
      actionIdentifier = null,
      appState = null,
      date = Variant_Double_String.create(System.currentTimeMillis().toDouble()),
    )
    HybridAliPushPlugin.dispatch(message)
  }

  override fun onMessage(context: Context?, intent: android.content.Intent?) {
    val message = intent?.getSerializableExtra("message") as? CPushMessage
    val extras = AnyMap()
    message?.let {
      extras.setString("appId", it.appId ?: "")
      extras.setString("messageId", it.messageId ?: "")
    }
    intent?.extras?.let { putBundle(extras, it) }
    val payload = AliPushMessage(
      title = message?.title,
      subtitle = null,
      body = message?.content,
      badge = null,
      extras = extras,
      type = AliPushMessageType.MESSAGE,
      actionIdentifier = null,
      appState = null,
      date = Variant_Double_String.create(System.currentTimeMillis().toDouble()),
    )
    HybridAliPushPlugin.dispatch(payload)
  }

  override fun onNotificationOpened(
    context: Context?,
    title: String?,
    summary: String?,
    extraMap: Map<String, String>?,
  ) {
    val message = AliPushMessage(
      title = title,
      subtitle = null,
      body = summary,
      badge = null,
      extras = buildExtras(extraMap),
      type = AliPushMessageType.NOTIFICATION,
      actionIdentifier = "opened",
      appState = null,
      date = Variant_Double_String.create(System.currentTimeMillis().toDouble()),
    )
    HybridAliPushPlugin.dispatch(message)
  }

  override fun onNotificationRemoved(context: Context?, messageId: String?) {
    val extras = AnyMap()
    if (messageId != null) extras.setString("messageId", messageId)
    val message = AliPushMessage(
      title = null,
      subtitle = null,
      body = null,
      badge = null,
      extras = extras,
      type = AliPushMessageType.NOTIFICATION,
      actionIdentifier = "removed",
      appState = null,
      date = Variant_Double_String.create(System.currentTimeMillis().toDouble()),
    )
    HybridAliPushPlugin.dispatch(message)
  }

  override fun onChannelRegistration(context: Context?, errorCode: String?) {
    Log.d("AliPush", "onChannelRegistration: $errorCode")
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  private fun buildExtras(extraMap: Map<String, String>?): AnyMap? {
    if (extraMap.isNullOrEmpty()) return null
    val map = AnyMap()
    for ((k, v) in extraMap) {
      map.setString(k, v)
    }
    return map
  }

  private fun putBundle(target: AnyMap, bundle: Bundle) {
    bundle.keySet()?.forEach { key ->
      when (val value = bundle.get(key)) {
        is String -> target.setString(key, value)
        is Double -> target.setDouble(key, value)
        is Int -> target.setDouble(key, value.toDouble())
        is Boolean -> target.setBoolean(key, value)
        is Long -> target.setInt64(key, value)
      }
    }
  }

  companion object {
    /**
     * 由中转 Activity 传入点击通知的 `Bundle`，组装并派发到 JS。
     * 第三方通道的通知点击数据通常放在 `Intent` 的 extras 中。
     */
    fun dispatchFromIntent(extras: Bundle?) {
      if (extras == null) return
      val title = extras.getString("title")
      val body = extras.getString("body") ?: extras.getString("summary")
      val e = AnyMap()
      extras.keySet()?.forEach { key ->
        (extras.get(key) as? String)?.let { e.setString(key, it) }
      }
      val message = AliPushMessage(
        title = title,
        subtitle = null,
        body = body,
        badge = null,
        extras = e,
        type = AliPushMessageType.NOTIFICATION,
        actionIdentifier = "opened",
        appState = null,
        date = Variant_Double_String.create(System.currentTimeMillis().toDouble()),
      )
      HybridAliPushPlugin.dispatch(message)
    }
  }
}
