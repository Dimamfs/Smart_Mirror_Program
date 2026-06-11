package com.smartmirror.smart_mirror_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val hotspotPlugin by lazy { HotspotPlugin(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.smartmirror/hotspot"
        ).setMethodCallHandler { call, result ->
            @Suppress("UNCHECKED_CAST")
            hotspotPlugin.onMethodCall(
                call.method,
                call.arguments as? Map<String, Any?>,
                result,
            )
        }
    }
}
