# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Flutter native entrypoints
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Desugar JDK libs
-keep class java.time.** { *; }
-dontwarn java.time.**

# Keep local database and models
-keepclassmembers class * implements java.io.Serializable { *; }

# Suppress Play Core and Deferred Components warnings
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Firebase & Google Services
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
