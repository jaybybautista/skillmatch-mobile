/// Company settings — the same `users` and `companies` columns the website's
/// settings page reads and writes.
library;

import '../core/json_parse.dart';

/// One recent sign-in, as the security section lists it.
class LoginActivityEntry {
  const LoginActivityEntry({
    required this.id,
    required this.ipAddress,
    required this.userAgent,
    required this.atHuman,
    required this.at,
  });

  final int id;
  final String? ipAddress;
  final String? userAgent;
  final String atHuman;
  final String? at;

  /// The browser or app name out of the user agent, since the full string is
  /// unreadable on a phone.
  String get device {
    final agent = userAgent;
    if (agent == null || agent.isEmpty) return 'Unknown device';

    for (final name in const ['Edg', 'Chrome', 'Firefox', 'Safari', 'Dart']) {
      if (agent.contains(name)) return name == 'Edg' ? 'Edge' : name;
    }
    return 'Unknown device';
  }

  factory LoginActivityEntry.fromJson(Map<String, dynamic> json) =>
      LoginActivityEntry(
        id: asInt(json['id']),
        ipAddress: json['ip_address'] as String?,
        userAgent: json['user_agent'] as String?,
        atHuman: json['at_human'] as String? ?? '',
        at: json['at'] as String?,
      );
}

/// The recruitment preferences that steer matching and notifications.
class CompanyPreferences {
  const CompanyPreferences({
    required this.contactEmail,
    required this.contactNumber,
    required this.notifyApplications,
    required this.notifyAssessments,
    required this.notifyPlacements,
    required this.minMatchThreshold,
    required this.defaultWorkType,
    required this.workingHours,
  });

  final String? contactEmail;
  final String? contactNumber;
  final bool notifyApplications;
  final bool notifyAssessments;
  final bool notifyPlacements;

  /// The match score below which candidates are hidden from Browse
  /// candidates. This is why that screen can open with a floor already set.
  final int minMatchThreshold;

  final String? defaultWorkType;
  final String? workingHours;

  factory CompanyPreferences.fromJson(Map<String, dynamic> json) =>
      CompanyPreferences(
        contactEmail: json['contact_email'] as String?,
        contactNumber: json['contact_number'] as String?,
        notifyApplications: json['notify_applications'] as bool? ?? true,
        notifyAssessments: json['notify_assessments'] as bool? ?? true,
        notifyPlacements: json['notify_placements'] as bool? ?? true,
        minMatchThreshold: asInt(json['min_match_threshold']),
        defaultWorkType: json['default_work_type'] as String?,
        workingHours: json['working_hours'] as String?,
      );
}

/// Everything the settings screen shows.
class CompanySettings {
  const CompanySettings({
    required this.name,
    required this.email,
    required this.preferences,
    required this.workTypes,
    required this.loginActivity,
  });

  final String name;
  final String email;
  final CompanyPreferences preferences;

  /// The work arrangements a posting can default to, from the backend so the
  /// two platforms can't offer different ones.
  final List<String> workTypes;

  final List<LoginActivityEntry> loginActivity;

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>? ?? const {};

    return CompanySettings(
      name: account['name'] as String? ?? '',
      email: account['email'] as String? ?? '',
      preferences: CompanyPreferences.fromJson(
        json['preferences'] as Map<String, dynamic>? ?? const {},
      ),
      workTypes: (json['work_types'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
      loginActivity: (json['login_activity'] as List? ?? const [])
          .map((e) => LoginActivityEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
