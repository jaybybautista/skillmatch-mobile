import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/editable_profile.dart';

void main() {
  group('CampusOption', () {
    test('carries the programs its campus offers', () {
      final campus = CampusOption.fromJson(const {
        'id': 9,
        'name': 'Urdaneta City Campus',
        'programs': [
          'Bachelor of Science in Civil Engineering',
          'Bachelor of Science in Information Technology',
        ],
      });

      expect(campus.programs, hasLength(2));
      expect(
        campus.programs.first,
        'Bachelor of Science in Civil Engineering',
      );
    });

    test('a campus with no programs listed parses as empty, not null', () {
      final campus = CampusOption.fromJson(const {'id': 1, 'name': 'Infanta'});

      expect(campus.programs, isEmpty);
    });
  });
}
