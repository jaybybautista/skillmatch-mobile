class StudentInfo {
  StudentInfo({
    required this.course,
    required this.yearLevel,
    required this.campus,
    required this.campusId,
    required this.setupComplete,
  });

  final String? course;
  final int? yearLevel;
  final String? campus;
  final int? campusId;
  final bool setupComplete;

  factory StudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      course: json['course'] as String?,
      yearLevel: json['year_level'] as int?,
      campus: json['campus'] as String?,
      campusId: json['campus_id'] as int?,
      setupComplete: json['setup_complete'] as bool? ?? false,
    );
  }
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.givenName,
    this.familyName,
    this.profilePictureUrl,
    this.student,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String status;

  /// `users.first_name` / `users.last_name`. Older tokens and any payload that
  /// predates the split can still be missing them, so they stay nullable and
  /// [firstName] falls back to the composed name.
  final String? givenName;
  final String? familyName;
  final String? profilePictureUrl;
  final StudentInfo? student;

  String get firstName {
    final given = givenName?.trim();
    if (given != null && given.isNotEmpty) return given;
    return name.trim().split(' ').first;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      givenName: json['first_name'] as String?,
      familyName: json['last_name'] as String?,
      email: json['email'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      student: json['student'] != null ? StudentInfo.fromJson(json['student'] as Map<String, dynamic>) : null,
    );
  }
}
