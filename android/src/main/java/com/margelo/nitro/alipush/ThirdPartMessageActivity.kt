package com.margelo.nitro.alipush

import android.app.Activity
import android.os.Bundle
import android.util.Log

/**
 * 第三方通道（小米 / 华为 / 魅族 / OPPO / vivo 等）通知点击后的中转 Activity。
 *
 * 在 `AndroidManifest.xml` 中以 `android:exported="true"` + 合适的 `intent-filter`
 * 注册后，用户点击系统通知会先拉起本 Activity，由其把通知数据通过
 * [AliPushMessageReceiver.dispatchFromIntent] 派发到 JS。若宿主 App 不需要此中转逻辑，
 * 可忽略本类。
 */
class ThirdPartMessageActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    try {
      // 由广播接收器统一处理通知点击数据。
      AliPushMessageReceiver.dispatchFromIntent(intent?.extras)
    } catch (e: Exception) {
      Log.e("AliPush", "ThirdPartMessageActivity error", e)
    }
    finish()
  }
}
