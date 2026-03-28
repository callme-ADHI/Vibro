package com.vibro.vibro

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.app.KeyguardManager
import android.content.Context
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val LAUNCH_CHANNEL = "com.vibro.app/launch"
    private val SERVICE_CHANNEL = "com.vibro.vibro/foreground_service"
    private var autoOpenTriggered = false
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val isAutoOpenExtra = intent.getBooleanExtra("auto_open", false)
        val payload = intent.getStringExtra("payload")
        autoOpenTriggered = isAutoOpenExtra || payload == "auto_open" || payload == "navigate_to_captions"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Launch/Auto-open channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCH_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getAutoOpen") {
                result.success(autoOpenTriggered)
                autoOpenTriggered = false
            } else {
                result.notImplemented()
            }
        }

        // Register NSD plugin
        flutterEngine.plugins.add(VibroNsdPlugin())

        // Foreground service control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val mode = call.argument<String>("mode") ?: "deaf"
                        val intent = Intent(this, VibroForegroundService::class.java).apply {
                            action = VibroForegroundService.ACTION_START
                            putExtra(VibroForegroundService.EXTRA_MODE, mode)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        val intent = Intent(this, VibroForegroundService::class.java).apply {
                            action = VibroForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        val isAutoOpenExtra = intent.getBooleanExtra("auto_open", false)
        val payload = intent.getStringExtra("payload")
        if (isAutoOpenExtra || payload == "auto_open" || payload == "navigate_to_captions") {
            autoOpenTriggered = true
            methodChannel?.invokeMethod("onAutoOpenTriggered", true)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }
}
