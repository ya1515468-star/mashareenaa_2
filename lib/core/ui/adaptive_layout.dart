import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global UI adaptation for Mashareena.
///
/// The app is authored against a stable reference canvas (390x844 logical
/// pixels), then scaled as a single visual surface to fit the real device.
/// The logical MediaQuery size is adjusted at the same time so existing
/// responsive code sees the adapted canvas rather than the raw device size.
///
/// This intentionally does not change business logic, hit testing or
/// server-side behaviour.
class MashareenaAdaptiveMetrics {
  const MashareenaAdaptiveMetrics({
    required this.screenSize,
    required this.logicalSize,
    required this.scale,
  });

  static const double referenceWidth = 390;
  static const double referenceHeight = 844;
  static const double minScale = 0.82;
  static const double maxScale = 1.15;

  final Size screenSize;
  final Size logicalSize;
  final double scale;

  double px(double value) => value * scale;
  double width(double value) => value * (logicalSize.width / referenceWidth);
  double height(double value) => value * (logicalSize.height / referenceHeight);

  static double calculateScale({
    required Size size,
    required EdgeInsets viewInsets,
  }) {
    if (size.width <= 0 || size.height <= 0) {
      return 1;
    }

    // Include the keyboard inset when deciding scale. This prevents the
    // entire app from shrinking when the keyboard appears.
    final effectiveHeight = size.height + viewInsets.vertical;
    final widthScale = size.width / referenceWidth;
    final heightScale = effectiveHeight / referenceHeight;
    final rawScale = math.min(widthScale, heightScale);

    return rawScale.clamp(minScale, maxScale).toDouble();
  }
}

class MashareenaAdaptiveScope extends InheritedWidget {
  const MashareenaAdaptiveScope({
    required this.metrics,
    required super.child,
    super.key,
  });

  final MashareenaAdaptiveMetrics metrics;

  static MashareenaAdaptiveMetrics of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<MashareenaAdaptiveScope>()
            ?.metrics ??
        const MashareenaAdaptiveMetrics(
          screenSize: Size(390, 844),
          logicalSize: Size(390, 844),
          scale: 1,
        );
  }

  @override
  bool updateShouldNotify(MashareenaAdaptiveScope oldWidget) {
    final old = oldWidget.metrics;
    return old.scale != metrics.scale ||
        old.logicalSize != metrics.logicalSize ||
        old.screenSize != metrics.screenSize;
  }
}

extension MashareenaAdaptiveContext on BuildContext {
  MashareenaAdaptiveMetrics get adaptive => MashareenaAdaptiveScope.of(this);

  double adaptivePx(double value) => adaptive.px(value);

  double adaptiveWidth(double value) => adaptive.width(value);

  double adaptiveHeight(double value) => adaptive.height(value);
}

/// Applies the adaptation globally to the application's route surface.
///
/// This is intentionally placed at [MaterialApp.builder] so every route,
/// dialog, bottom sheet and overlay created under the Navigator receives the
/// same sizing behaviour.
class MashareenaAdaptiveShell extends StatelessWidget {
  const MashareenaAdaptiveShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final scale = MashareenaAdaptiveMetrics.calculateScale(
      size: screenSize,
      viewInsets: media.viewInsets,
    );
    final logicalSize = Size(
      screenSize.width / scale,
      screenSize.height / scale,
    );

    EdgeInsets scaleInsets(EdgeInsets value) {
      return EdgeInsets.fromLTRB(
        value.left / scale,
        value.top / scale,
        value.right / scale,
        value.bottom / scale,
      );
    }

    final metrics = MashareenaAdaptiveMetrics(
      screenSize: screenSize,
      logicalSize: logicalSize,
      scale: scale,
    );

    // Flutter web's viewport/mouse tracking pipeline is sensitive to a
    // transformed scrollable route surface. The auth page is a
    // SingleChildScrollView, so keep native web constraints and hit testing
    // while still exposing the calculated adaptive metrics.
    if (kIsWeb) {
      return MashareenaAdaptiveScope(
        metrics: metrics,
        child: child,
      );
    }

    final adaptedMedia = media.copyWith(
      size: logicalSize,
      padding: scaleInsets(media.padding),
      viewPadding: scaleInsets(media.viewPadding),
      viewInsets: scaleInsets(media.viewInsets),
    );

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: logicalSize.width,
          height: logicalSize.height,
          child: Transform.scale(
            alignment: Alignment.topCenter,
            scale: scale,
            child: MediaQuery(
              data: adaptedMedia,
              child: MashareenaAdaptiveScope(
                metrics: metrics,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
