# Flutter secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Audio players
-keep class xyz.luan.audioplayers.** { *; }

# Kotlin
-dontwarn kotlin.**

# Flutter Play Store deferred components (not used, suppress R8 warnings)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# MapLibre GL — JNI bridge classes must not be renamed or removed by R8
-keep class org.maplibre.** { *; }
-keep interface org.maplibre.** { *; }
-dontwarn org.maplibre.**

# Razorpay checkout SDK relies on reflection to invoke the host app's payment
# callbacks. NOTE: -optimizations is a global R8 directive with no package-scope
# syntax — this disables the method/removal/parameter optimization pass for the
# ENTIRE app, not just Razorpay, even though it's declared in this section.
# Without it, minification silently breaks the checkout flow instead of throwing
# a build error.
-keep class com.razorpay.** {*;}
-dontwarn com.razorpay.**
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
-optimizations !method/removal/parameter
-keepattributes JavascriptInterface
-keepattributes Signature

# Geolocator — its Android implementation lives under com.baseflow.geolocator (not
# io.flutter.plugins.**, so the broad Flutter-plugin rule above never covered it),
# including a permission/ subpackage that handles the
# ActivityCompat.OnRequestPermissionsResultCallback used by SplashScreen's location
# permission flow. Without this, R8 can strip/rename that callback class under
# minification (enabled for release since the v36 Play Console fixes commit, which
# never added a rule for this plugin) — the permission-request Future then never
# completes, hanging the splash screen forever in release builds only (debug never
# runs R8, so this was invisible until a real release build was tested).
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**
