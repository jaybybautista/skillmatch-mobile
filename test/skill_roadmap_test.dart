import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/skill_roadmap.dart';
import 'package:skillmatch/screens/roadmap/skill_roadmap_screen.dart';
import 'package:skillmatch/services/skill_roadmap_service.dart';

class _FakeSkillRoadmapService extends SkillRoadmapService {
  _FakeSkillRoadmapService({this.roadmap, this.error});

  final SkillRoadmap? roadmap;
  final Object? error;

  @override
  Future<SkillRoadmap> fetch() async {
    if (error != null) throw error!;
    return roadmap!;
  }
}

SkillRoadmap _roadmap({
  List<String> possessed = const ['Laravel', 'Php'],
  List<String> suggested = const ['React', 'Docker'],
  List<String> trending = const ['Laravel', 'Php', 'React', 'Docker'],
  Map<String, int> demand = const {'Laravel': 3, 'Php': 3, 'React': 2, 'Docker': 1},
  List<Map<String, dynamic>> steps = const [
    {
      'timeframe': 'Weeks 1-3',
      'title': 'Learn the missing skills',
      'description': 'Start with React, Docker.',
      'suggested_skills': ['React', 'Docker'],
    },
    {
      'timeframe': 'Ongoing',
      'title': 'Apply to postings that fit',
      'description': 'Once your profile reflects the above, apply.',
      'suggested_skills': [],
    },
  ],
}) {
  return SkillRoadmap.fromJson({
    'possessed_skills': possessed,
    'suggested_skills': suggested,
    'trending_skills': trending,
    'skill_demand': demand,
    'steps': steps,
  });
}

void main() {
  group('SkillRoadmap model', () {
    test('parses every field from the API shape', () {
      final roadmap = _roadmap();

      expect(roadmap.possessedSkills, ['Laravel', 'Php']);
      expect(roadmap.suggestedSkills, ['React', 'Docker']);
      expect(roadmap.trendingSkills, hasLength(4));
      expect(roadmap.skillDemand['Laravel'], 3);
      expect(roadmap.steps, hasLength(2));
      expect(roadmap.steps.first.suggestedSkills, ['React', 'Docker']);
    });

    test('masteryFraction is possessed over trending', () {
      final roadmap = _roadmap(
        possessed: ['A', 'B', 'C'],
        trending: ['A', 'B', 'C', 'D', 'E', 'F'],
      );

      expect(roadmap.masteryFraction, 0.5);
    });

    test('masteryFraction is zero when there is no market data yet', () {
      final roadmap = _roadmap(possessed: const [], trending: const [], demand: const {});
      expect(roadmap.masteryFraction, 0);
    });
  });

  group('SkillRoadmapScreen', () {
    testWidgets('shows suggested skills with their demand count', (tester) async {
      final service = _FakeSkillRoadmapService(roadmap: _roadmap());

      await tester.pumpWidget(MaterialApp(home: SkillRoadmapScreen(service: service)));
      await tester.pumpAndSettle();

      // "React" appears twice by design — once as a suggested chip, once
      // again inside the plan step that focuses on it.
      expect(find.text('React'), findsWidgets);
      expect(find.textContaining('2 postings'), findsOneWidget);
    });

    testWidgets('shows the possessed-skills section when there are some', (tester) async {
      final service = _FakeSkillRoadmapService(roadmap: _roadmap());
      await tester.pumpWidget(MaterialApp(home: SkillRoadmapScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Already on your profile'), findsOneWidget);
    });

    testWidgets('hides the possessed-skills section when there are none', (tester) async {
      final service = _FakeSkillRoadmapService(
        roadmap: _roadmap(possessed: const [], trending: const ['React', 'Docker']),
      );
      await tester.pumpWidget(MaterialApp(home: SkillRoadmapScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Already on your profile'), findsNothing);
    });

    testWidgets('renders the suggested plan as numbered steps', (tester) async {
      final service = _FakeSkillRoadmapService(roadmap: _roadmap());

      await tester.pumpWidget(MaterialApp(home: SkillRoadmapScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Learn the missing skills'), findsOneWidget);
      expect(find.text('Weeks 1-3'), findsOneWidget);

      // Below the fold in the default test viewport.
      await tester.scrollUntilVisible(find.text('Apply to postings that fit'), 300);
      expect(find.text('Apply to postings that fit'), findsOneWidget);
    });

    testWidgets('a load failure shows a retryable error', (tester) async {
      final service = _FakeSkillRoadmapService(error: Exception('offline'));

      await tester.pumpWidget(MaterialApp(home: SkillRoadmapScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
