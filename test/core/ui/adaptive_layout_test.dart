import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mashareena/core/ui/adaptive_layout.dart';

void main() {
  group('MashareenaAdaptiveMetrics.calculateScale', () {
    test('keeps the reference device at 1.0', () {
      final scale = MashareenaAdaptiveMetrics.calculateScale(
        size: const Size(390, 844),
        viewInsets: EdgeInsets.zero,
      );

      expect(scale, 1);
    });

    test('scales a narrow phone down without going below the safety floor', () {
      final scale = MashareenaAdaptiveMetrics.calculateScale(
        size: const Size(320, 568),
        viewInsets: EdgeInsets.zero,
      );

      expect(scale, MashareenaAdaptiveMetrics.minScale);
    });

    test('scales a larger phone up but respects the upper cap', () {
      final scale = MashareenaAdaptiveMetrics.calculateScale(
        size: const Size(1440, 2960),
        viewInsets: EdgeInsets.zero,
      );

      expect(scale, MashareenaAdaptiveMetrics.maxScale);
    });

    test('keyboard inset does not shrink the app unexpectedly', () {
      final withoutKeyboard = MashareenaAdaptiveMetrics.calculateScale(
        size: const Size(390, 844),
        viewInsets: EdgeInsets.zero,
      );
      final withKeyboard = MashareenaAdaptiveMetrics.calculateScale(
        size: const Size(390, 500),
        viewInsets: const EdgeInsets.only(bottom: 344),
      );

      expect(withKeyboard, withoutKeyboard);
    });
  });
}
