# Mashareena release baseline. Flutter/R8 generated rules remain authoritative.
# Keep Flutter plugin registrants and platform channel classes discoverable.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# Flutter's deferred-components embedding references these optional Play Core classes.
# Mashareenaa does not use deferred components, so suppress their absent-class warnings during R8.
-dontwarn com.google.android.play.core.**
