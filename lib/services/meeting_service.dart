import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/meeting.dart';
import '../models/messaging/conversation.dart';
import 'call_manager.dart';

/// Online meetings (interviews) on applications: the student's confirm /
/// reschedule answers, the company's schedule / move / cancel / complete,
/// and joining the room, which is the same Jitsi room the website opens.
class MeetingService {
  final ApiClient _client = ApiClient.instance;

  /* ── Student ─────────────────────────────────────────────────────── */

  Future<(Meeting, String)> respond(int meetingId, {required String action, DateTime? proposedAt, String? note}) async {
    final response = await _client.post('/student/meetings/$meetingId/respond', {
      'action': action,
      if (proposedAt != null) 'proposed_at': proposedAt.toIso8601String(),
      if (note != null && note.isNotEmpty) 'note': note,
    }, authenticated: true);
    return (Meeting.fromJson(response['meeting'] as Map<String, dynamic>), response['message'] as String? ?? '');
  }

  Future<String> respondToOffer(int applicationId, {required bool accept}) async {
    final response = await _client.post('/student/applications/$applicationId/offer', {
      'action': accept ? 'accept' : 'decline',
    }, authenticated: true);
    return response['message'] as String? ?? '';
  }

  /* ── Company ─────────────────────────────────────────────────────── */

  Future<(Meeting, String)> schedule(
    int applicationId, {
    required String title,
    String? agenda,
    required String type,
    required bool startNow,
    DateTime? scheduledAt,
    required int durationMinutes,
  }) async {
    final response = await _client.post('/company/applications/$applicationId/meetings', {
      'title': title,
      if (agenda != null && agenda.isNotEmpty) 'agenda': agenda,
      'type': type,
      'mode': startNow ? 'now' : 'scheduled',
      if (!startNow) 'scheduled_at': ?scheduledAt?.toIso8601String(),
      'duration_minutes': durationMinutes,
    }, authenticated: true);
    return (Meeting.fromJson(response['meeting'] as Map<String, dynamic>), response['message'] as String? ?? '');
  }

  Future<(Meeting, String)> reschedule(int meetingId, {required DateTime scheduledAt, int? durationMinutes}) async {
    final response = await _client.patch('/company/meetings/$meetingId', {
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': ?durationMinutes,
    }, authenticated: true);
    return (Meeting.fromJson(response['meeting'] as Map<String, dynamic>), response['message'] as String? ?? '');
  }

  Future<(Meeting, String)> cancel(int meetingId) async {
    final response = await _client.post('/company/meetings/$meetingId/cancel', {}, authenticated: true);
    return (Meeting.fromJson(response['meeting'] as Map<String, dynamic>), response['message'] as String? ?? '');
  }

  Future<(Meeting, String)> complete(int meetingId) async {
    final response = await _client.post('/company/meetings/$meetingId/complete', {}, authenticated: true);
    return (Meeting.fromJson(response['meeting'] as Map<String, dynamic>), response['message'] as String? ?? '');
  }

  /* ── Both ────────────────────────────────────────────────────────── */

  /// Enters the meeting room in the native call screen and tells the server
  /// when it closes. Throws [ApiException] when the room is not open yet.
  Future<void> join(int meetingId) async {
    final response = await _client.post('/meetings/$meetingId/join', {}, authenticated: true);
    final join = response['join'] as Map<String, dynamic>;
    final cfg = CallJoinConfig.fromJson(join);
    final type = join['type'] as String? ?? 'video';

    await CallManager.instance.joinRoom(
      cfg,
      audioOnly: type == 'audio',
      onLeft: () async {
        try {
          await _client.post('/meetings/$meetingId/leave', {}, authenticated: true);
        } catch (_) {}
      },
    );
  }

  /// Joins and reports problems on a snackbar; used by both sides' cards.
  Future<bool> joinWithFeedback(BuildContext context, int meetingId) async {
    try {
      await join(meetingId);
      return true;
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the meeting room.')));
      }
    }
    return false;
  }
}
