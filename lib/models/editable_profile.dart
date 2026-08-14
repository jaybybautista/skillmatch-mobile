import 'student_profile.dart' show ResumeInfo;

class CampusOption {
  CampusOption({required this.id, required this.name});

  final int id;
  final String name;

  factory CampusOption.fromJson(Map<String, dynamic> json) {
    return CampusOption(id: json['id'] as int, name: json['name'] as String);
  }
}

/// Raw field values behind the Edit Profile form — the display profile is
/// already formatted for reading, so editing needs the underlying values.
class EditableProfile {
  EditableProfile({
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.email,
    this.studentNumber,
    this.contactNumber,
    this.campusId,
    this.course,
    this.yearLevel,
    this.address,
    this.region,
    this.province,
    this.cityMunicipality,
    this.barangay,
    this.resume,
    required this.campuses,
  });

  /// `users.first_name` / `users.last_name` — the two columns the web profile
  /// page edits. `name` is the composed display value the model keeps in sync.
  final String firstName;
  final String lastName;
  final String name;
  final String email;
  final String? studentNumber;
  final String? contactNumber;
  final int? campusId;
  final String? course;
  final int? yearLevel;
  final String? address;
  final String? region;
  final String? province;
  final String? cityMunicipality;
  final String? barangay;
  final ResumeInfo? resume;
  final List<CampusOption> campuses;

  factory EditableProfile.fromJson(Map<String, dynamic> json) {
    return EditableProfile(
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      studentNumber: json['student_number'] as String?,
      contactNumber: json['contact_number'] as String?,
      campusId: (json['campus_id'] as num?)?.toInt(),
      course: json['course'] as String?,
      yearLevel: (json['year_level'] as num?)?.toInt(),
      address: json['address'] as String?,
      region: json['region'] as String?,
      province: json['province'] as String?,
      cityMunicipality: json['city_municipality'] as String?,
      barangay: json['barangay'] as String?,
      resume: json['resume'] != null ? ResumeInfo.fromJson(json['resume'] as Map<String, dynamic>) : null,
      campuses: (json['campuses'] as List? ?? []).map((e) => CampusOption.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
