# Add project-specific ProGuard rules here.
# Flutter's default rules are applied automatically by the Flutter Gradle plugin.

# Keep classes referenced from the AndroidManifest (Activities, Services, Receivers)
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.appwidget.AppWidgetProvider

# Keep Flutter / plugin classes
-keep class io.flutter.** { *; }
-keep class io.amer.scanner.** { *; }

# Keep MLKit / Google Play Services (reflection-based)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep mobile_scanner native bindings
-keep class io.github.edufolly.** { *; }
-keep class com.tomergoldst.** { *; }

-dontwarn com.google.mlkit.**
-dontwarn io.github.edufolly.**
