import 'package:flutter/foundation.dart';

/// Global media-focus gate. Only the active product surface may own playback.
class AppMediaPlaybackCoordinator {
  AppMediaPlaybackCoordinator._();
  static final ValueNotifier<String?> scope = ValueNotifier<String?>(null);

  static const producerMarket = 'producer_market';

  static void setScope(String? value) {
    if (scope.value == value) return;
    scope.value = value;
  }

  static bool owns(String owner) => scope.value == owner;
}
