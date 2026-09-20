import 'package:flutter/material.dart';

/// Global route observer used by media owners that must stop when another
/// route or modal is placed above them.
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();
