# Add project specific ProGuard rules here.
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Core (for deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep Kotlin Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Keep ML Kit / TensorFlow if used
-keep class org.tensorflow.** { *; }
-keep class com.google.mlkit.** { *; }

# Prevent R8 from stripping interface information
-keep,allowobfuscation,allowshrinking interface * {
    <methods>;
}
