package com.vibro.vibro

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.content.Intent

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.vibro.app/launch"
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
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getAutoOpen") {
                result.success(autoOpenTriggered)
                autoOpenTriggered = false
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Need to reset intent so that the new one replaces the old one
        setIntent(intent)
        
        val isAutoOpenExtra = intent.getBooleanExtra("auto_open", false)
        val payload = intent.getStringExtra("payload")
        if (isAutoOpenExtra || payload == "auto_open" || payload == "navigate_to_captions") {
            autoOpenTriggered = true
            // Push to Flutter immediately if channel is ready
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
