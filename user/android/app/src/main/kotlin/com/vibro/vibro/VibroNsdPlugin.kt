package com.vibro.vibro

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.InetAddress

/**
 * VIBRO NSD Plugin — handles Android Network Service Discovery (mDNS)
 * for local WiFi peer discovery without any backend.
 *
 * Channels:
 *   MethodChannel  "com.vibro.vibro/nsd"       → registerService / unregisterService
 *                                                 startDiscovery / stopDiscovery
 *   EventChannel   "com.vibro.vibro/nsd_events" → found / lost events to Dart
 */
class VibroNsdPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private var nsdManager: NsdManager? = null

    // Registration (Deaf server)
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var registeredServiceName: String? = null

    // Discovery (Connected client)
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        const val SERVICE_TYPE = "_vibro._tcp."
        const val TAG = "VibroNSD"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager

        methodChannel = MethodChannel(binding.binaryMessenger, "com.vibro.vibro/nsd")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.vibro.vibro/nsd_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        safeStopDiscovery()
        safeUnregisterService()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "registerService" -> {
                val serviceType = call.argument<String>("serviceType") ?: SERVICE_TYPE
                val serviceName = call.argument<String>("serviceName") ?: "VIBRO-CONNECT"
                val port = call.argument<Int>("port") ?: 47476
                registerService(serviceName, port, result)
            }
            "unregisterService" -> {
                safeUnregisterService()
                result.success(null)
            }
            "startDiscovery" -> {
                startDiscovery(result)
            }
            "stopDiscovery" -> {
                safeStopDiscovery()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── Register service (Deaf phone = server) ──────────────────────────────
    private fun registerService(name: String, port: Int, result: Result) {
        safeUnregisterService()

        val serviceInfo = NsdServiceInfo().apply {
            serviceName = name
            serviceType = SERVICE_TYPE
            setPort(port)
        }

        registrationListener = object : NsdManager.RegistrationListener {
            override fun onRegistrationFailed(info: NsdServiceInfo?, errorCode: Int) {
                android.util.Log.e(TAG, "Registration failed: $errorCode")
                mainHandler.post { result.error("NSD_REG_FAILED", "Error $errorCode", null) }
            }

            override fun onUnregistrationFailed(info: NsdServiceInfo?, errorCode: Int) {
                android.util.Log.e(TAG, "Unregistration failed: $errorCode")
            }

            override fun onServiceRegistered(info: NsdServiceInfo?) {
                registeredServiceName = info?.serviceName
                android.util.Log.d(TAG, "Service registered: ${info?.serviceName}")
                mainHandler.post { result.success(info?.serviceName) }
            }

            override fun onServiceUnregistered(info: NsdServiceInfo?) {
                android.util.Log.d(TAG, "Service unregistered")
            }
        }

        try {
            nsdManager?.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Register error: ${e.message}")
            result.error("NSD_EXCEPTION", e.message, null)
        }
    }

    private fun safeUnregisterService() {
        registrationListener?.let {
            try {
                nsdManager?.unregisterService(it)
            } catch (_: Exception) {}
            registrationListener = null
        }
    }

    // ── Discover services (Connected phone = client) ─────────────────────────
    private fun startDiscovery(result: Result) {
        safeStopDiscovery()

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String?, errorCode: Int) {
                android.util.Log.e(TAG, "Start discovery failed: $errorCode")
                mainHandler.post { result.error("NSD_DISC_FAILED", "Error $errorCode", null) }
            }

            override fun onStopDiscoveryFailed(serviceType: String?, errorCode: Int) {
                android.util.Log.e(TAG, "Stop discovery failed: $errorCode")
            }

            override fun onDiscoveryStarted(serviceType: String?) {
                android.util.Log.d(TAG, "Discovery started")
                mainHandler.post { result.success(null) }
            }

            override fun onDiscoveryStopped(serviceType: String?) {
                android.util.Log.d(TAG, "Discovery stopped")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo?) {
                serviceInfo ?: return
                android.util.Log.d(TAG, "Service found: ${serviceInfo.serviceName}")
                // Resolve to get host/port
                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo?) {
                serviceInfo ?: return
                android.util.Log.d(TAG, "Service lost: ${serviceInfo.serviceName}")
                mainHandler.post {
                    eventSink?.success(mapOf(
                        "event" to "lost",
                        "name" to serviceInfo.serviceName,
                        "host" to (serviceInfo.host?.hostAddress ?: ""),
                        "port" to serviceInfo.port
                    ))
                }
            }
        }

        try {
            nsdManager?.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Discover error: ${e.message}")
            result.error("NSD_EXCEPTION", e.message, null)
        }
    }

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        @Suppress("DEPRECATION")
        nsdManager?.resolveService(serviceInfo, object : NsdManager.ResolveListener {
            override fun onResolveFailed(info: NsdServiceInfo?, errorCode: Int) {
                android.util.Log.e(TAG, "Resolve failed: $errorCode")
            }
            override fun onServiceResolved(info: NsdServiceInfo?) {
                info ?: return
                emitFoundEvent(info)
            }
        })
    }

    private fun emitFoundEvent(info: NsdServiceInfo) {
        val host = info.host?.hostAddress ?: return
        val port = info.port
        val name = info.serviceName ?: "VIBRO-CONNECT"
        android.util.Log.d(TAG, "Resolved: $name @ $host:$port")

        mainHandler.post {
            eventSink?.success(mapOf(
                "event" to "found",
                "name" to name,
                "host" to host,
                "port" to port
            ))
        }
    }

    private fun safeStopDiscovery() {
        discoveryListener?.let {
            try {
                nsdManager?.stopServiceDiscovery(it)
            } catch (_: Exception) {}
            discoveryListener = null
        }
    }
}
