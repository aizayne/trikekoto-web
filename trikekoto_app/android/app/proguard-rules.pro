# Shrinking is enabled only for genuinely signed release builds.
#
# Flutter's own engine classes are referenced reflectively from native code,
# so R8 cannot see those references and would strip them.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase and Play Services reference members reflectively as well.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Crashlytics needs line numbers and source names to symbolicate a stack
# trace. Without these, a field crash report is a list of addresses.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Play Core — referenced by Flutter's deferred-components support, which this
# app does not use. Specifying proguardFiles explicitly overrides Flutter's
# own default rules, so these keeps have to be restated here or R8 fails on
# classes that are never actually loaded.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
