package com.example.heart_beat

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

#if DEBUG
/// DEBUG-only log bridge that captures logcat output and forwards it
/// over a Flutter MethodChannel so lines can be written to the native-android
/// log file alongside rust, dart, and native-ios logs.
class LogBridge(private val activity: FlutterActivity) {
    private val channel = MethodChannel(
        activity.binaryMessenger,
        "heart_beat/native_log"
    )

    private var logcatProcess: Process? = null
    private var backgroundThread: Thread? = null

    fun start() {
        try {
            // Get the current process ID
            val pid = android.os.Process.myPid()

            // Start logcat with threadtime format (includes timestamp, thread, tag)
            // Filter to only this app's PID
            logcatProcess = Runtime.getRuntime().exec(
                arrayOf("logcat", "-v", "threadtime", "--pid=$pid")
            )

            backgroundThread = Thread {
                readLoop()
            }
            backgroundThread?.name = "LogBridge.readLoop"
            backgroundThread?.priority = Thread.MIN_PRIORITY
            backgroundThread?.start()
        } catch (e: Exception) {
            android.util.Log.e("LogBridge", "Failed to start logcat: $e")
        }
    }

    private fun readLoop() {
        try {
            val reader = logcatProcess?.inputStream?.bufferedReader() ?: return

            var line: String?
            while (true) {
                line = reader.readLine()
                if (line == null) break

                // Skip empty lines
                if (line.isEmpty()) continue

                // Forward to Flutter via main thread
                activity.runOnUiThread {
                    try {
                        channel.invokeMethod("onNativeLog", line)
                    } catch (e: Exception) {
                        // Channel might not be ready yet, ignore
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("LogBridge", "readLoop error: $e")
        } finally {
            try {
                logcatProcess?.destroy()
            } catch (_: Exception) {
            }
        }
    }

    fun dispose() {
        backgroundThread?.interrupt()
        backgroundThread = null

        try {
            logcatProcess?.destroy()
            logcatProcess = null
        } catch (_: Exception) {
        }
    }
}
#endif