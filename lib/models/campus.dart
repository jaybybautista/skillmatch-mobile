class Campus {
  Campus({
    required this.id,
    required this.name,
    required this.programs,
  });

  final int id;
  final String name;
  final List<String> programs;

  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      id: json['id'] as int,
      name: json['name'] as String,
      programs: (json['programs'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
