import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/profile_setup.dart';
import 'package:skillmatch/screens/student/setup/setup_wizard_screen.dart';

/// The exact shape GeminiAiService::parseResumeText promises.
Map<String, dynamic> _aiResponse() => {
      'parsed': {
        'basic_info': {
          'full_name': 'Godfrey Javier',
          'address': 'Sta.Maria, Pangasinan',
          'zip_code': '2240',
          'phone_number': '09263408919',
          'email': 'godfreyjavier@gmail.com',
        },
        'education': [
          {'degree': 'BS Information Technology', 'school_name': 'PSU Urdaneta'},
        ],
        'experience': [
          {'job_title': 'IT Support', 'company': 'TechCorp Inc', 'responsibilities': 'Helpdesk'},
        ],
        'achievements': [
          {'title': 'Google IT Support', 'category': 'Coursera', 'date_text': '2023'},
          {'title': ''},
        ],
        'skills': {
          'technical': ['React', 'Python'],
          'soft': ['Communication'],
        },
      },
      'resume_name': 'Sample_resume.pdf',
    };

void main() {
  group('ParsedResume', () {
    test('reads the AI parse, including full_name', () {
      final parsed = ParsedResume.fromJson(_aiResponse());

      expect(parsed.basicInfo.name, 'Godfrey Javier');
      expect(parsed.basicInfo.zipCode, '2240');
      expect(parsed.education.single.schoolName, 'PSU Urdaneta');
      expect(parsed.experience.single.jobTitle, 'IT Support');
      expect(parsed.technicalSkills, ['React', 'Python']);
      expect(parsed.softSkills, ['Communication']);
      expect(parsed.resumeName, 'Sample_resume.pdf');
    });

    test('drops untitled achievements rather than showing blank rows', () {
      final parsed = ParsedResume.fromJson(_aiResponse());
      expect(parsed.certifications.map((c) => c.title), ['Google IT Support']);
    });

    test('survives a sparse response without throwing', () {
      final parsed = ParsedResume.fromJson({'parsed': <String, dynamic>{}});

      expect(parsed.basicInfo.name, isNull);
      expect(parsed.education, isEmpty);
      expect(parsed.technicalSkills, isEmpty);
    });

    test('empty() gives a blank starting point for filling in manually', () {
      final parsed = ParsedResume.empty();
      expect(parsed.technicalSkills, isEmpty);
      expect(parsed.certifications, isEmpty);
    });
  });

  group('SetupState', () {
    test('reads the flag and the prefill', () {
      final state = SetupState.fromJson({
        'needs_setup': true,
        'setup_complete': false,
        'setup_skipped': false,
        'prefill': {'name': 'ZZ Probe', 'email': 'probe@example.invalid'},
      });

      expect(state.needsSetup, isTrue);
      expect(state.prefill.name, 'ZZ Probe');
    });

    test('defaults to not needing setup when the payload is empty', () {
      // A malformed response must not trap an existing student in the wizard.
      expect(SetupState.fromJson(const {}).needsSetup, isFalse);
    });
  });

  testWidgets('the wizard prefills step 1 from the scanned resume', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SetupWizardScreen(parsed: ParsedResume.fromJson(_aiResponse())),
    ));
    await tester.pumpAndSettle();

    // Everything the scan understood is on screen for review before saving.
    expect(find.text('Godfrey Javier'), findsOneWidget);
    expect(find.text('Sta.Maria, Pangasinan'), findsOneWidget);
    expect(find.text('2240'), findsOneWidget);
    expect(find.text('09263408919'), findsOneWidget);
    expect(find.text('godfreyjavier@gmail.com'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('About you'), findsNWidgets(2)); // progress label + heading
  });

  group('Experience', () {
    test('formats a period from whichever dates exist', () {
      Experience make(String? start, String? end) => Experience.fromJson({
            'id': 1,
            'position': 'IT Support',
            'organization': 'TechCorp',
            'start_date': start,
            'end_date': end,
          });

      expect(make('Jun 2021', 'Aug 2024').period, 'Jun 2021–Aug 2024');
      expect(make('Jun 2021', null).period, 'Jun 2021');
      expect(make(null, 'Aug 2024').period, 'Aug 2024');
      expect(make(null, null).period, '');
    });
  });
}
