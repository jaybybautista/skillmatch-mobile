import 'package:flutter/widgets.dart';

import 'app_routing.dart';

/// Refetches a screen's data when it is uncovered.
///
/// The home screens are the reason this exists. They are held by the launch
/// gate — the first route — and load once, in `initState`. Everything else
/// is pushed on top of them, and the sidebar's "Home" unwinds back down
/// rather than building a new one, so their state survives the whole
/// session. That is deliberate: clearing the stack to rebuild them would
/// take the gate with it, and with it the app's ability to route the next
/// login.
///
/// The cost is that numbers on a home screen can be older than the work
/// just done on top of it — accept an applicant, tap Home, and the posting
/// carousel still shows the slot count from when the app opened. Reloading
/// on the way back closes that gap without touching the route stack.
///
/// Only fires when the screen is *revealed*, not on every notification, so
/// a screen buried three deep costs nothing until it is actually seen.
mixin RefreshOnReveal<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<void>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is! ModalRoute<void> || identical(route, _route)) return;

    if (_route != null) routeObserver.unsubscribe(this);
    _route = route;
    routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    if (_route != null) routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => onReveal();

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}

  /// Reload whatever this screen shows. Called each time the screen above
  /// it closes.
  void onReveal();
}
