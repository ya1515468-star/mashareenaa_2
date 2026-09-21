# Mashareena release shrinking rules.
# Keep plugin registrants and plugin platform/channel classes discoverable.
# Do not keep all of io.flutter.embedding: unused deferred-component code
# would otherwise retain legacy Play Core references and inflate release size.
-keep class io.flutter.plugins.** { *; }

# Flutter 3.47.2 may reference optional deferred-component Play Core classes
# even though Mashareena does not ship deferred components.
-dontwarn com.google.android.play.core.**

-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
