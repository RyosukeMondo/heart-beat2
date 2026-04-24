package com.example.heart_beat

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
#if DEBUG
    private var logBridge: LogBridge? = null
#endif

    init {
        // Load native library to ensure JNI_OnLoad is called
        // This initializes ndk-context for btleplug Android support
        System.loadLibrary("heart_beat")
    }

#if DEBUG
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        logBridge = LogBridge(this)
        logBridge?.start()
    }

    override fun onDestroy() {
        logBridge?.dispose()
        logBridge = null
        super.onDestroy()
    }
#endif
}
