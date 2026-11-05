package com.mylawyer.my_lawyer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // إشعارات الطلبات تظهر فوق الشاشة وبصوت لأن المهلة 60 ثانية
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("alerts", "الطلبات", NotificationManager.IMPORTANCE_HIGH).apply { enableVibration(true) }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    // خطوات تجهيز موبايل المحامي عشان تجيله طلبات وهو برّه التطبيق
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mylawyer/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "notificationsEnabled" -> {
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.N || manager.areNotificationsEnabled())
                }
                "batteryExempt" -> {
                    val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(power.isIgnoringBatteryOptimizations(packageName))
                }
                "openBatterySettings" -> {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    result.success(null)
                }
                "alert" -> {
                    RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))?.play()
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(300)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
