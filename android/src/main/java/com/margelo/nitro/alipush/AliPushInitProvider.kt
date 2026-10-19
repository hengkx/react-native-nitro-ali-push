package com.margelo.nitro.alipush

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import com.alibaba.sdk.android.push.noonesdk.PushServiceFactory

/**
 * 阿里云推送框架加载器（无操作 ContentProvider）。
 *
 * 阿里云官方要求「2.1 初始化」必须在 `Application.onCreate` 中执行，用于加载推送框架、
 * 初始化推送参数；该阶段**不启动推送逻辑、不采集任何隐私数据**。
 *
 * `ContentProvider.onCreate()` 由系统在 `Application.attachBaseContext` 之后、
 * `Application.onCreate` **之前**回调，因此本库无需宿主写任何原生代码即可满足该时序要求。
 *
 * 真正涉及设备标识采集的 `register(...)`（阿里云通道 + 各厂商通道）不在这里调用 ——
 * 由 JS 侧在用户同意隐私后调用 `register` 触发（见 `HybridAliPushPlugin.register`）。
 */
class AliPushInitProvider : ContentProvider() {
  override fun onCreate(): Boolean {
    val context = context ?: return false
    return try {
      // 只加载框架与参数；appKey/appSecret 缺失时 SDK 会自行从 manifest meta-data 读取。
      PushServiceFactory.init(context.applicationContext)
      true
    } catch (_: Throwable) {
      // 初始化失败不应导致 App 启动崩溃，交由后续 register 报错。
      false
    }
  }

  // 以下为 ContentProvider 必须实现的空接口，本 Provider 不对外提供数据。
  override fun query(
    uri: Uri,
    projection: Array<String>?,
    selection: String?,
    selectionArgs: Array<String>?,
    sortOrder: String?,
  ): Cursor? = null

  override fun getType(uri: Uri): String? = null

  override fun insert(uri: Uri, values: ContentValues?): Uri? = null

  override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0

  override fun update(
    uri: Uri,
    values: ContentValues?,
    selection: String?,
    selectionArgs: Array<String>?,
  ): Int = 0
}
