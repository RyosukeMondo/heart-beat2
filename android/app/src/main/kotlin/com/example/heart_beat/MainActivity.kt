package com.example.heart_beat

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    init {
        // Load native library to ensure JNI_OnLoad is called
        // This initializes ndk-context for btleplug Android support
        System.loadLibrary("heart_beat")
    }
}
