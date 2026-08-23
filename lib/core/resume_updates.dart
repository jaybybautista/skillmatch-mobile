import 'package:flutter/widgets.dart';

import 'app_routing.dart';

/// Announces that a resume changed, so every screen showing resume data
/// refreshes itself instead of waiting to be reopened.
///
/// A resume is not shown in one place. The list carries each resume's title
/// and when it was last touched; the section list carries what is in it; the
/// preview renders the whole thing; and importing one auto-fills the
/// student's profile with the skills, education and experience the parser
/// read out of it. Before this, each of those refetched only when it was
/// built — so editing a section left the list behind it claiming the resume
/// was last updated an hour ago, and importing left the profile empty until
/// it happened to be rebuilt.
///
/// Every write in ResumeService reports here, and every screen that shows
/// resume data listens. There is nothing to register and nothing to pass
/// down: a screen subscribes in `initState` and reloads when told.
///
/// **What this does not do:** it does not hear about edits made in the
/// browser. Nothing in this app holds a socket open, so a change made on the
/// web shows up on the next fetch — pulling to refresh, reopening the
/// screen, or bringing the app back to the foreground. This keeps the phone
/// consistent with itself, immediately.
class ResumeUpdates extends ChangeNotifier {
  ResumeUpdates._();

  static final ResumeUpdates instance = ResumeUpdates._();

  /// Bumped on every change. Exposed so a listener can tell whether it has
  /// already caught up with the latest one.
  int revision = 0;

  /// Says a resume changed. Safe to call from anywhere, including from a
  /// service that has no idea which screens are on the stack.
  void changed() {
    revision++;
    notifyListeners();
  }
}

/// Reloads a screen whenever a resume changes anywhere in the app.
///
/// Mix this into a [State] and implement [onResumeChanged] with whatever
/// that screen already does to refetch. Subscribing and unsubscribing are
/// handled here, so no screen can leak a listener by forgetting to.
///
/// A screen the student is looking at reloads the instant the change lands.
/// One buried under another waits until it is uncovered, and then reloads
/// once for everything it missed. That second part matters more than it
/// looks: the section editors save while you type, on a 700ms debounce, so
/// a single paragraph is a dozen changes. Reloading every screen on the
/// stack for each of them would be a dozen wasted round trips for something
/// nobody can see — and it would arrive at the same place this does.
mixin ResumeUpdateListener<T extends StatefulWidget> on State<T>
    implements RouteAware {
  /// The last change this screen has already caught up with, so a
  /// notification it caused itself does not read as news.
  int _seen = ResumeUpdates.instance.revision;

  /// False while another screen is on top of this one.
  bool _visible = true;

  /// Kept so the same route is unsubscribed on the way out.
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    ResumeUpdates.instance.addListener(_handleResumeUpdate);
  }

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
    ResumeUpdates.instance.removeListener(_handleResumeUpdate);
    super.dispose();
  }

  void _handleResumeUpdate() {
    // Out of sight: remember nothing, because [_seen] staying behind is
    // exactly what makes the catch-up on the way back work.
    if (_visible) _catchUp();
  }

  void _catchUp() {
    if (!mounted) return;

    final revision = ResumeUpdates.instance.revision;
    if (revision == _seen) return;
    _seen = revision;

    onResumeChanged();
  }

  @override
  void didPush() => _visible = true;

  @override
  void didPushNext() => _visible = false;

  @override
  void didPop() => _visible = false;

  @override
  void didPopNext() {
    _visible = true;
    // Everything that happened while this screen was covered collapses into
    // one reload here.
    _catchUp();
  }

  /// Refetch whatever this screen shows.
  void onResumeChanged();
}
