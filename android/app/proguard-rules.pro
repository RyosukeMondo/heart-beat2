# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.

# Keep Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Rust FFI interface
-keep class com.example.heart_beat.rust.** { *; }

# Keep BLE related classes
-keep class * extends android.bluetooth.** { *; }

# btleplug Android BLE library (accessed via JNI from Rust)
-keep class com.nonpolynomial.** { *; }
-keep class io.github.gedgygedgy.** { *; }

# Ignore Play Core library warnings (not using deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
