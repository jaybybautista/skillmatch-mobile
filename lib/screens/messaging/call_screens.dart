import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/messaging/conversation.dart';
import '../../services/call_manager.dart';
import '../../services/messaging_service.dart';
import 'widgets/chat_avatar.dart';

/// "Calling…" while the other side's phone or browser rings.
///
/// Starts the call, then watches the conversation every 2 seconds: when the
/// callee accepts, the Jitsi room opens; when they decline, do not answer, or
/// the ring times out on the server, the screen says so and closes. Cancel
/// hangs up before anyone answered. A group call has nobody to wait for, so
/// the starter is put straight into the room.
class OutgoingCallScreen extends StatefulWidget {
  const OutgoingCallScreen({super.key, required this.conversation, required this.type});

  final Conversation conversation;
  final String type; // audio | video

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  final _service = MessagingService.instance;
  CallSession? _session;
  Timer? _watch;
  String _status = 'Calling…';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final session = await _service.startCall(widget.conversation.id, widget.type);
      if (!mounted) return;
      _session = session;

      if (session.isGroup) {
        await _enterRoom(session);
        return;
      }

      setState(() => _status = 'Ringing…');
      _watch = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    } on ApiException catch (e) {
      _finish(e.message);
    } catch (_) {
      _finish('Could not start the call.');
    }
  }

  Future<void> _check() async {
    final session = _session;
    if (session == null || _done) return;
    try {
      final page = await _service.thread(widget.conversation.id);
      final live = page.conversation.activeCall;
      if (!mounted || _done) return;

      if (live == null || live.id != session.callId) {
        final last = page.conversation.lastMessage;
        _finish(last != null && last.isCall && last.preview.startsWith('Declined') ? 'Declined' : 'No answer');
        return;
      }
      if (live.status == 'accepted') {
        _watch?.cancel();
        await _enterRoom(session);
      }
    } catch (_) {
      // Keep ringing; the next tick checks again.
    }
  }

  Future<void> _enterRoom(CallSession session) async {
    if (_done) return;
    _done = true;
    _watch?.cancel();
    if (mounted) setState(() => _status = 'Connecting…');
    try {
      await CallManager.instance.join(session, audioOnly: session.type == 'audio');
    } catch (_) {
      // join() already told the server the call ended.
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    if (_done) return;
    _done = true;
    _watch?.cancel();
    final session = _session;
    if (session != null) {
      try {
        await _service.cancelCall(session.callId);
      } catch (_) {}
    }
    _service.touchList();
    if (mounted) Navigator.of(context).pop();
  }

  void _finish(String message) {
    if (_done) return;
    _done = true;
    _watch?.cancel();
    if (!mounted) return;
    setState(() => _status = message);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return _CallScaffold(
      name: c.name,
      initial: c.initial,
      avatarUrl: c.displayAvatar,
      square: c.isGroup || c.user?.role == 'company',
      caption: '${widget.type == 'video' ? 'Video' : 'Audio'} call · $_status',
      actions: [
        _RoundAction(icon: Icons.call_end, color: AppColors.danger, label: 'Cancel', onTap: _cancel),
      ],
    );
  }
}

/// Someone is calling me. Accept opens the room; Decline tells them.
///
/// Closes itself when the caller gives up (the poll no longer reports the
/// call) so the phone does not keep ringing for nobody.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.call});

  final PendingCall call;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _service = MessagingService.instance;
  Timer? _buzz;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _service.pendingCall.addListener(_onPendingChanged);
    HapticFeedback.vibrate();
    _buzz = Timer.periodic(const Duration(milliseconds: 1500), (_) => HapticFeedback.vibrate());
  }

  @override
  void dispose() {
    _buzz?.cancel();
    _service.pendingCall.removeListener(_onPendingChanged);
    super.dispose();
  }

  void _onPendingChanged() {
    if (_answered) return;
    final now = _service.pendingCall.value;
    if (now == null || now.id != widget.call.id) {
      // Caller hung up, or it was answered on another device.
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _accept() async {
    if (_answered) return;
    _answered = true;
    _buzz?.cancel();
    try {
      final session = await _service.acceptCall(widget.call.id);
      if (!mounted) return;
      await CallManager.instance.join(session, audioOnly: session.type == 'audio');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
    _service.touchList();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _decline() async {
    if (_answered) return;
    _answered = true;
    _buzz?.cancel();
    try {
      await _service.declineCall(widget.call.id);
    } catch (_) {}
    _service.touchList();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final caller = call.caller;
    final title = call.isGroup ? (call.conversationName ?? 'Group') : (caller?.name ?? 'Someone');
    final caption = call.isGroup
        ? '${caller?.firstName ?? 'Someone'} started a ${call.type} call'
        : 'Incoming ${call.type} call';

    return PopScope(
      canPop: false,
      child: _CallScaffold(
        name: title,
        initial: caller?.initial ?? '?',
        avatarUrl: caller?.avatarUrl,
        square: caller?.role == 'company',
        caption: caption,
        actions: [
          _RoundAction(icon: Icons.call_end, color: AppColors.danger, label: 'Decline', onTap: _decline),
          _RoundAction(
            icon: call.type == 'video' ? Icons.videocam : Icons.call,
            color: const Color(0xFF16A34A),
            label: 'Accept',
            onTap: _accept,
          ),
        ],
      ),
    );
  }
}

class _CallScaffold extends StatelessWidget {
  const _CallScaffold({
    required this.name,
    required this.initial,
    required this.caption,
    required this.actions,
    this.avatarUrl,
    this.square = false,
  });

  final String name;
  final String initial;
  final String? avatarUrl;
  final bool square;
  final String caption;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            ChatAvatar(initial: initial, url: avatarUrl, size: 112, square: square),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: AppFonts.title(color: Colors.white, fontSize: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(caption, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

/// Sits above the whole app: whenever the poll reports a call ringing for
/// me, pushes [IncomingCallScreen] on the root navigator (unless I am
/// already in a call). The web shows the same banner on every page.
class IncomingCallRinger extends StatefulWidget {
  const IncomingCallRinger({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<IncomingCallRinger> createState() => _IncomingCallRingerState();
}

class _IncomingCallRingerState extends State<IncomingCallRinger> {
  final _service = MessagingService.instance;
  int? _showingCallId;

  @override
  void initState() {
    super.initState();
    _service.pendingCall.addListener(_onCall);
  }

  @override
  void dispose() {
    _service.pendingCall.removeListener(_onCall);
    super.dispose();
  }

  Future<void> _onCall() async {
    final call = _service.pendingCall.value;
    if (call == null || call.id == _showingCallId) return;
    if (CallManager.instance.inCall) return;

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    _showingCallId = call.id;
    await navigator.push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => IncomingCallScreen(call: call)),
    );
    _showingCallId = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
