package com.vibro.vibro

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SERVICE_CHANNEL = "com.vibro.vibro/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
}
