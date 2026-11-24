package com.example.alice_app

import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Saluran "alice/device": dipakai DeviceReporter untuk membaca
        // suhu baterai. Android melaporkannya dalam persepuluh derajat.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alice/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "batteryTemperature") {
                    val intent = registerReceiver(
                        null,
                        IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                    )
                    val tenths = intent?.getIntExtra(
                        BatteryManager.EXTRA_TEMPERATURE,
                        Int.MIN_VALUE
                    ) ?: Int.MIN_VALUE

                    if (tenths == Int.MIN_VALUE) {
                        result.success(null)
                    } else {
                        result.success(tenths / 10.0)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}