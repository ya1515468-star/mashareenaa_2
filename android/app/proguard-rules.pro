# Mashareena release shrinking rules.
# Keep plugin registrants and plugin platform/channel classes discoverable.
# Do not keep all of io.flutter.embedding: unused deferred-component code
# would otherwise retain the legacy Play Core references and inflate release size.
-keep class io.flutter.plugins.** { *; }
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
