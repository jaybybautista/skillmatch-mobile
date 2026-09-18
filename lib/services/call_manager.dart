import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../models/messaging/conversation.dart';
import 'messaging_service.dart';

/// Puts the phone into a Jitsi room and tells SkillMatch when it leaves.
///
/// SkillMatch owns the ringing (who calls whom, accept / decline, when it
/// ended); Jitsi carries the audio and video. The `join` payload the call
/// endpoints return (domain, room, jwt, display name) is exactly what the
/// native Jitsi SDK needs, so the app joins the same room the website does.
///
/// The SDK opens its own full-screen native activity; when the person hangs
/// up there (or the room ends), [conferenceTerminated] fires and the call is
/// closed on the server through `POST /messages/calls/{id}/end`.
class CallManager {
  CallManager._();

  static final CallManager instance = CallManager._();

  final JitsiMeet _jitsi = JitsiMeet();
  final MessagingService _messaging = MessagingService.instance;

  /// The call I am inside right now, if any (one live call per person).
  final ValueNotifier<int?> activeCallId = ValueNotifier<int?>(null);

  bool get inCall => activeCallId.value != null;

  /// Joins the room for [session]. [audioOnly] starts with the camera off.
  /// Completes once the native call screen has been closed and the server
  /// told; the caller decides what to show afterwards.
  Future<void> join(CallSession session, {required bool audioOnly}) {
    return joinRoom(
      session.join,
      audioOnly: audioOnly,
      callId: session.callId,
      onLeft: () async {
        try {
          await _messaging.endCall(session.callId);
        } catch (_) {
          // The server times the call out on its own if this never lands.
        }
        _messaging.touchList();
      },
    );
  }

  /// Joins any Jitsi room described by a `join` payload: a call, or an
  /// online meeting (interview) from an application. [onLeft] runs once,
  /// after the native screen closes, to tell the server.
  Future<void> joinRoom(
    CallJoinConfig cfg, {
    required bool audioOnly,
    required Future<void> Function() onLeft,
    int? callId,
  }) async {
    final completer = Completer<void>();
    var closed = false;

    Future<void> finish() async {
      if (closed) return;
      closed = true;
      activeCallId.value = null;
      await onLeft();
      if (!completer.isCompleted) completer.complete();
    }

    activeCallId.value = callId ?? -1;

    final options = JitsiMeetConferenceOptions(
      serverURL: cfg.serverUrl,
      room: cfg.room,
      token: cfg.jwt,
      configOverrides: {
        'subject': cfg.subject,
        'startWithAudioMuted': false,
        'startWithVideoMuted': audioOnly,
        'prejoinConfig': {'enabled': false},
        'disableDeepLinking': true,
      },
      featureFlags: {
        'prejoinpage.enabled': false,
        'unsaferoomwarning.enabled': false,
        'welcomepage.enabled': false,
        'invite.enabled': false,
        'add-people.enabled': false,
        'calendar.enabled': false,
        'recording.enabled': false,
        'live-streaming.enabled': false,
        'meeting-name.enabled': true,
        'pip.enabled': true,
        'help.enabled': false,
        'security-options.enabled': false,
        'lobby-mode.enabled': false,
        'car-mode.enabled': false,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: cfg.displayName,
        email: cfg.email,
        avatar: cfg.avatarUrl,
      ),
    );

    final listener = JitsiMeetEventListener(
      conferenceTerminated: (url, error) => finish(),
      readyToClose: finish,
    );

    try {
      await _jitsi.join(options, listener);
    } catch (e) {
      debugPrint('Jitsi join failed: $e');
      await finish();
      rethrow;
    }

    return completer.future;
  }

  Future<void> hangUp() async {
    try {
      await _jitsi.hangUp();
    } catch (_) {}
  }
}
