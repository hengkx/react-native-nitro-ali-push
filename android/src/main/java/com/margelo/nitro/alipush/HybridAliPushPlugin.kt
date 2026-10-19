package com.margelo.nitro.alipush

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.alibaba.sdk.android.push.CommonCallback
import com.alibaba.sdk.android.push.HonorRegister
import com.alibaba.sdk.android.push.huawei.HuaWeiRegister
import com.alibaba.sdk.android.push.noonesdk.PushServiceFactory
import com.alibaba.sdk.android.push.register.MeizuRegister
import com.alibaba.sdk.android.push.register.MiPushRegister
import com.alibaba.sdk.android.push.register.OppoRegister
import com.alibaba.sdk.android.push.register.VivoRegister
import com.margelo.nitro.core.NullType
import com.margelo.nitro.core.Promise
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * react-native-nitro-ali-push 的 Android 原生实现（Kotlin，Nitro HybridObject）。
 *
 * 通过 `nitrogen` 生成的 `HybridAliPushPluginSpec` 抽象类暴露给 JS。推送事件通过静态
 * 监听器池（`listeners`）直接派发到 JS 回调，不再依赖 `ReactApplicationContext` /
 * `DeviceEventManagerModule`（这正是 Nitro 与原 TurboModule 实现的主要差异）。
 */
class HybridAliPushPlugin : HybridAliPushPluginSpec() {
  /** 记录最近一次设置的应用角标，供 `getApplicationIconBadgeNumber` 返回。 */
  private var badgeNumber: Double = 0.0

  // MARK: - 静态事件池（供广播接收器调用）

  companion object {
    private val listeners = mutableMapOf<Int, (AliPushMessage) -> Unit>()
    private var listenerSeq = 0
    private var initialMessage: AliPushMessage? = null

    /**
     * 由广播接收器调用，把推送载荷派发到 JS（无监听器时缓存首条冷启动消息）。
     */
    @JvmStatic
    fun dispatch(message: AliPushMessage) {
      if (listeners.isEmpty()) {
        if (initialMessage == null) initialMessage = message
        return
      }
      listeners.values.forEach { it.invoke(message) }
    }

    /** 读取并清空缓存的首条冷启动消息。 */
    @JvmStatic
    fun consumeInitialMessage(): AliPushMessage? {
      val m = initialMessage
      initialMessage = null
      return m
    }
  }

  // MARK: - 获取 Application Context

  private fun appContext(): Context {
    return try {
      val clazz = Class.forName("android.app.ActivityThread")
      val currentApp = clazz.getMethod("currentApplication").invoke(null) as? Application
      currentApp?.applicationContext
        ?: throw RuntimeException("Application context unavailable")
    } catch (e: Exception) {
      throw RuntimeException("Failed to obtain Application context", e)
    }
  }

  // MARK: - 初始化 / 设备号

  override fun registerPush(): Promise<Unit> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        try {
          val applicationContext = appContext()
          // appKey / appSecret 由 AliPushInitProvider 的 PushServiceFactory.init 决定
          // （读 AndroidManifest 的 com.alibaba.app.appkey / appsecret）。
          // 注意：SDK 的 4 参 register(Context, appKey, appSecret, cb) 已废弃 —— 内部直接
          // onFailed（提示改用 init），切勿使用。这里必须走 2 参版本。
          PushServiceFactory.getCloudPushService()
            .register(applicationContext, object : CommonCallback {
              override fun onSuccess(response: String?) {
                // 阿里云通道注册成功后，再注册 manifest 里配置了参数的厂商通道。
                registerVendorChannels()
                cont.resume(Unit)
              }
              override fun onFailed(errorCode: String?, errorMessage: String?) =
                cont.resumeWithException(RuntimeException("register failed: $errorCode $errorMessage"))
            })
        } catch (e: Throwable) {
          cont.resumeWithException(e)
        }
      }
    }
  }

  /**
   * 逐个注册各厂商通道。
   *
   * 每个 `XxxRegister.register` 内部都做了品牌判断，非本品牌设备会直接跳过，因此这里无需
   * 自己判机型。华为 / 荣耀 / vivo 不需要 appId（由厂商 SDK 自行读取 manifest 或
   * agconnect-services.json）；小米 / OPPO / 魅族必须传参，从 manifest meta-data 读取。
   * 单家厂商缺失配置或抛异常都不影响其他厂商与主流程。
   */
  private fun registerVendorChannels() {
    val ctx = appContext()
    val app = ctx.applicationContext as? Application

    // 华为 / 荣耀：需要 Application，appId 由厂商 SDK 自己读
    if (app != null) {
      runCatching { HuaWeiRegister.register(app) }
      runCatching { HonorRegister.register(app) }
    }

    // vivo：无参，由 vivo SDK 读 manifest
    runCatching { VivoRegister.register(ctx) }

    // 小米 / OPPO / 魅族：需显式传参，从 manifest meta-data 读取
    val miId = manifestMeta(ctx, "com.xiaomi.push.id")
    val miKey = manifestMeta(ctx, "com.xiaomi.push.key")
    if (miId != null && miKey != null) {
      runCatching { MiPushRegister.register(ctx, miId, miKey) }
    }

    val oppoKey = manifestMeta(ctx, "com.oppo.push.key")
    val oppoSecret = manifestMeta(ctx, "com.oppo.push.secret")
    if (oppoKey != null && oppoSecret != null) {
      runCatching { OppoRegister.register(ctx, oppoKey, oppoSecret) }
    }

    val meizuId = manifestMeta(ctx, "com.meizu.push.id")
    val meizuKey = manifestMeta(ctx, "com.meizu.push.key")
    if (meizuId != null && meizuKey != null) {
      runCatching { MeizuRegister.register(ctx, meizuId, meizuKey) }
    }
  }

  /**
   * 读取宿主 `AndroidManifest.xml` 中 `<application>` 下的 meta-data。
   *
   * 纯数字在 manifest 合并时可能被转成科学计数法，故官方推荐加 `id=` 前缀，这里一并去掉。
   */
  private fun manifestMeta(context: Context, key: String): String? {
    return try {
      val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        context.packageManager.getApplicationInfo(
          context.packageName,
          PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
        )
      } else {
        @Suppress("DEPRECATION")
        context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
      }
      val raw = appInfo.metaData?.getString(key) ?: return null
      raw.trim().removePrefix("id=").trim().takeIf { it.isNotEmpty() }
    } catch (_: Throwable) {
      null
    }
  }

  override fun getDeviceId(): Promise<String> {
    return Promise.parallel {
      PushServiceFactory.getCloudPushService().deviceId
        ?: throw RuntimeException("deviceId is null")
    }
  }

  // MARK: - 账号

  override fun bindAccount(account: String): Promise<Unit> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .bindAccount(
            account,
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(Unit)
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("bindAccount failed: $code $message"))
            },
          )
      }
    }
  }

  override fun unbindAccount(): Promise<Unit> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .unbindAccount(
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(Unit)
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("unbindAccount failed: $code $message"))
            },
          )
      }
    }
  }

  // MARK: - 标签

  override fun bindTag(
    target: Double,
    tags: Array<String>,
    alias: Variant_NullType_String?,
  ): Promise<Unit> {
    val aliasString = if (alias is Variant_NullType_String.Second) alias.value else null
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .bindTag(
            target.toInt(),
            tags,
            aliasString,
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(Unit)
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("bindTag failed: $code $message"))
            },
          )
      }
    }
  }

  override fun unbindTag(
    target: Double,
    tags: Array<String>,
    alias: Variant_NullType_String?,
  ): Promise<Unit> {
    val aliasString = if (alias is Variant_NullType_String.Second) alias.value else null
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .unbindTag(
            target.toInt(),
            tags,
            aliasString,
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(Unit)
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("unbindTag failed: $code $message"))
            },
          )
      }
    }
  }

  override fun listTags(target: Double): Promise<Array<String>> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .listTags(
            target.toInt(),
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(splitCommaList(response))
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("listTags failed: $code $message"))
            },
          )
      }
    }
  }

  /** 服务端以逗号拼接返回标签 / 别名，统一拆分为数组（去空白、丢空项）。 */
  private fun splitCommaList(response: String?): Array<String> {
    if (response.isNullOrBlank()) return emptyArray()
    return response
      .split(",")
      .map { it.trim() }
      .filter { it.isNotEmpty() }
      .toTypedArray()
  }

  // MARK: - 别名

  override fun addAlias(alias: String): Promise<Unit> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .addAlias(
            alias,
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(Unit)
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("addAlias failed: $code $message"))
            },
          )
      }
    }
  }

  override fun removeAlias(alias: String): Promise<Unit> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .removeAlias(
            alias,
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(Unit)
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("removeAlias failed: $code $message"))
            },
          )
      }
    }
  }

  override fun listAliases(): Promise<Array<String>> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        PushServiceFactory.getCloudPushService()
          .listAliases(
            object : CommonCallback {
              override fun onSuccess(response: String?) = cont.resume(splitCommaList(response))
              override fun onFailed(code: String?, message: String?) =
                cont.resumeWithException(RuntimeException("listAliases failed: $code $message"))
            },
          )
      }
    }
  }

  // MARK: - 角标

  override fun setApplicationIconBadgeNumber(badge: Double): Promise<Unit> {
    return Promise.parallel {
      PushServiceFactory.getCloudPushService().setBadgeNum(appContext(), badge.toInt())
      badgeNumber = badge
    }
  }

  override fun getApplicationIconBadgeNumber(): Promise<Double> {
    return Promise.resolved(badgeNumber)
  }

  override fun syncBadgeNum(badge: Double): Promise<Unit> {
    // Android 端阿里云推送无需单独同步角标，直接成功。
    return Promise.resolved()
  }

  // MARK: - 冷启动首条消息 & 授权状态

  override fun getInitialMessage(): Promise<Variant_NullType_AliPushMessage> {
    val message = consumeInitialMessage()
    return if (message != null) {
      Promise.resolved(Variant_NullType_AliPushMessage.create(message))
    } else {
      Promise.resolved(Variant_NullType_AliPushMessage.create(NullType))
    }
  }

  override fun getAuthorizationStatus(): Promise<Boolean> {
    return Promise.parallel {
      val context = appContext()
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.areNotificationsEnabled()
      } else {
        true
      }
    }
  }

  // MARK: - 事件订阅

  override fun addListener(listener: (message: AliPushMessage) -> Unit): () -> Unit {
    val id = ++listenerSeq
    listeners[id] = listener
    val cached = consumeInitialMessage()
    if (cached != null) listener(cached)
    return {
      listeners.remove(id)
    }
  }
}
