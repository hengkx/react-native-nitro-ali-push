package com.margelo.nitro.alipush

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import com.alibaba.sdk.android.push.CommonCallback
import com.alibaba.sdk.android.push.noonesdk.PushServiceFactory
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

  override fun initPush(appKey: String?, appSecret: String?): Promise<Unit> {
    return Promise.async {
      suspendCancellableCoroutine { cont ->
        try {
          val applicationContext = appContext()
          if (appKey != null && appSecret != null) {
            // 代码方式：带 appKey/appSecret 走 register(...)
            PushServiceFactory.init(applicationContext)
            PushServiceFactory.getCloudPushService()
              .register(
                applicationContext,
                appKey,
                appSecret,
                object : CommonCallback {
                  override fun onSuccess(response: String?) {
                    cont.resume(Unit)
                  }

                  override fun onFailed(errorCode: String?, errorMessage: String?) {
                    cont.resumeWithException(
                      RuntimeException("initPush failed: $errorCode $errorMessage")
                    )
                  }
                },
              )
          } else {
            // manifest 方式：SDK 从 AndroidManifest 读 com.alibaba.app.appkey/appsecret
            PushServiceFactory.init(applicationContext)
            PushServiceFactory.getCloudPushService()
              .register(
                applicationContext,
                object : CommonCallback {
                  override fun onSuccess(response: String?) {
                    cont.resume(Unit)
                  }

                  override fun onFailed(errorCode: String?, errorMessage: String?) {
                    cont.resumeWithException(
                      RuntimeException("initPush failed: $errorCode $errorMessage")
                    )
                  }
                },
              )
          }
        } catch (e: Throwable) {
          cont.resumeWithException(e)
        }
      }
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
