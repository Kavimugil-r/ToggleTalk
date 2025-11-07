package com.example.toggletalk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class WidgetBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "WidgetBroadcastReceiver"
        private const val CHANNEL = "com.example.toggletalk/widget"
        private const val TOGGLE_APPLIANCE_METHOD = "toggleAppliance"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")
        
        when (intent.action) {
            "com.example.toggletalk.TOGGLE_APPLIANCE" -> {
                val appliance = intent.getStringExtra("appliance") ?: return
                Log.d(TAG, "Toggling appliance: $appliance")
                
                // Get the Flutter engine from cache
                val flutterEngine = FlutterEngineCache.getInstance().get("my_engine_id")
                if (flutterEngine != null) {
                    val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                    channel.invokeMethod(TOGGLE_APPLIANCE_METHOD, mapOf("appliance" to appliance))
                } else {
                    Log.e(TAG, "Flutter engine not found in cache")
                }
            }
        }
    }
}