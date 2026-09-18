/// An online meeting (interview) on an application, as `MeetingService::present`
/// shapes it for both the student and the company.
class Meeting {
  const Meeting({
    required this.id,
    required this.applicationId,
    required this.title,
    required this.type,
    required this.instant,
    required this.durationMinutes,
    required this.whenLabel,
    required this.status,
    required this.statusLabel,
    required this.isOpen,
    required this.isJoinable,
    required this.isMissed,
    required this.opensLabel,
    this.agenda,
    this.scheduledAt,
    this.endsAt,
    this.proposedAt,
    this.proposedLabel,
    this.studentNote,
    this.companyJoinedAt,
    this.studentJoinedAt,
  });

  final int id;
  final int applicationId;
  final String title;
  final String? agenda;

  /// video | audio
  final String type;
  final bool instant;
  final DateTime? scheduledAt;
  final DateTime? endsAt;
  final int durationMinutes;
  final String whenLabel;

  /// scheduled | confirmed | reschedule_requested | completed | cancelled | missed
  final String status;
  final String statusLabel;
  final bool isOpen;
  final bool isJoinable;
  final bool isMissed;
  final String opensLabel;
  final DateTime? proposedAt;
  final String? proposedLabel;
  final String? studentNote;
  final DateTime? companyJoinedAt;
  final DateTime? studentJoinedAt;

  bool get isVideo => type == 'video';

  factory Meeting.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => DateTime.tryParse(json[key] as String? ?? '')?.toLocal();
    return Meeting(
      id: (json['id'] as num).toInt(),
      applicationId: (json['application_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Meeting',
      agenda: json['agenda'] as String?,
      type: json['type'] as String? ?? 'video',
      instant: json['instant'] as bool? ?? false,
      scheduledAt: date('scheduled_at'),
      endsAt: date('ends_at'),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      whenLabel: json['when_label'] as String? ?? '',
      status: json['status'] as String? ?? 'scheduled',
      statusLabel: json['status_label'] as String? ?? 'Scheduled',
      isOpen: json['is_open'] as bool? ?? true,
      isJoinable: json['is_joinable'] as bool? ?? false,
      isMissed: json['is_missed'] as bool? ?? false,
      opensLabel: json['opens_label'] as String? ?? '',
      proposedAt: date('proposed_at'),
      proposedLabel: json['proposed_label'] as String?,
      studentNote: json['student_note'] as String?,
      companyJoinedAt: date('company_joined_at'),
      studentJoinedAt: date('student_joined_at'),
    );
  }
}
