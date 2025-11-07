package com.example.toggletalk

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        // Cache the Flutter engine so the BroadcastReceiver can access it
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
    }
    
    override fun onDestroy() {
        // Clean up the cached engine when the activity is destroyed
        FlutterEngineCache.getInstance().remove("my_engine_id")
        super.onDestroy()
    }
}