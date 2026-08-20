import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/company_profile.dart';
import 'package:skillmatch/screens/company/edit_company_profile_screen.dart';
import 'package:skillmatch/services/company_service.dart';

class _FakeCompanyService extends CompanyService {
  _FakeCompanyService({this.error});

  final Object? error;
  final calls = <String>[];
  Map<String, String?> sent = const {};

  @override
  Future<CompanyProfile> updateProfile({
    required String companyName,
    String? industry,
    String? description,
    String? address,
    String? region,
    String? province,
    String? city,
    String? barangay,
    String? website,
    String? contactEmail,
    String? contactNumber,
  }) async {
    calls.add('update');
    if (error != null) throw error!;

    sent = {
      'company_name': companyName,
      'industry': industry,
      'description': description,
      'address': address,
      'region': region,
      'province': province,
      'city': city,
      'barangay': barangay,
      'website': website,
      'contact_email': contactEmail,
      'contact_number': contactNumber,
    };

    return _profile(name: companyName, industry: industry);
  }
}

CompanyProfile _profile({
  String name = 'Creatix Studio',
  String? industry = 'Design',
  String? description = 'We mentor interns on real work.',
  String? website = 'https://creatix.test',
  String? contactEmail = 'hr@creatix.test',
}) {
  return CompanyProfile.fromJson({
    'id': 1,
    'company_name': name,
    'industry': industry,
    'description': description,
    'address': 'Cebu City',
    'region': 'Region VII',
    'province': 'Cebu',
    'city': 'Cebu City',
    'barangay': 'Lahug',
    'website': website,
    'contact_email': contactEmail,
    'contact_number': '0917',
    'logo_url': null,
    'cover_url': null,
    'verification_status': 'approved',
    'is_verified': true,
    'stats': {
      'internship_count': 3,
      'open_slots': 12,
      'applicant_count': 7,
      'placement_count': 2,
    },
  });
}

Future<void> _pump(
  WidgetTester tester,
  CompanyService service, {
  CompanyProfile? profile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EditCompanyProfileScreen(
        profile: profile ?? _profile(),
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}

/// Back to the top. Validation messages sit under their field, which is
/// off-screen once the form has been scrolled down to reach Save.
Future<void> _scrollUp(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('opens prefilled with what the company already has', (
    tester,
  ) async {
    await _pump(tester, _FakeCompanyService());

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Creatix Studio'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, 'We mentor interns on real work.'),
      findsOneWidget,
    );

    await _scrollTo(tester, find.widgetWithText(TextFormField, 'Cebu City'));
    expect(find.widgetWithText(TextFormField, 'Lahug'), findsOneWidget);
  });

  testWidgets('saves every field the web form posts', (tester) async {
    final service = _FakeCompanyService();
    await _pump(tester, service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Creatix Studio'),
      'Creatix Labs',
    );

    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(service.calls, ['update']);
    expect(service.sent['company_name'], 'Creatix Labs');
    expect(service.sent['barangay'], 'Lahug');
    expect(service.sent['contact_number'], '0917');
    expect(service.sent['website'], 'https://creatix.test');
  });

  testWidgets('a company name is required', (tester) async {
    final service = _FakeCompanyService();
    await _pump(tester, service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Creatix Studio'),
      '   ',
    );

    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    await _scrollUp(tester);
    expect(find.text('A company name is required.'), findsOneWidget);
    expect(service.calls, isEmpty, reason: 'nothing should have been sent');
  });

  testWidgets('a half-typed website is caught before it reaches the server', (
    tester,
  ) async {
    final service = _FakeCompanyService();
    await _pump(tester, service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'https://creatix.test'),
      'creatix.test',
    );

    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // The server's own rule is `nullable|url`, which this would fail.
    await _scrollUp(tester);
    expect(find.text('Enter a full URL, including https://'), findsOneWidget);
    expect(service.calls, isEmpty);
  });

  testWidgets('clearing a field sends it empty rather than dropping it', (
    tester,
  ) async {
    final service = _FakeCompanyService();
    await _pump(tester, service);

    // Blanking the website has to actually blank it — sending nothing would
    // leave the old value in place.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'https://creatix.test'),
      '',
    );

    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(service.calls, ['update']);
    expect(service.sent['website'], '');
  });

  testWidgets('says so when the save fails, keeping what was typed', (
    tester,
  ) async {
    final service = _FakeCompanyService(error: Exception('offline'));
    await _pump(tester, service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Creatix Studio'),
      'Creatix Labs',
    );

    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save your profile'), findsOneWidget);

    await _scrollUp(tester);
    expect(find.widgetWithText(TextFormField, 'Creatix Labs'), findsOneWidget);
  });

  testWidgets('an industry the account already has is not silently dropped', (
    tester,
  ) async {
    final service = _FakeCompanyService();
    // 'Design' is not one of the website's fifteen options, but it is what
    // this account has stored.
    await _pump(tester, service, profile: _profile(industry: 'Design'));

    expect(find.text('Design'), findsOneWidget);

    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(service.sent['industry'], 'Design');
  });
}
