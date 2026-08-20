import 'package:flutter/widgets.dart';

/// Lets widgets react to being covered/uncovered by another route — used by
/// the floating chatbot button to return to its home position when you come
/// back to a screen.
///
/// Registered on [MaterialApp.navigatorObservers] in main.dart.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
