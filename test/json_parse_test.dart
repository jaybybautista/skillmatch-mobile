import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/core/json_parse.dart';
import 'package:skillmatch/models/company_analytics.dart';

void main() {
  group('numeric parsing tolerates stringly-typed numbers', () {
    test('asInt accepts both forms and never throws', () {
      expect(asInt(5), 5);
      expect(asInt('5'), 5);
      expect(asInt('5.9'), 5);
      expect(asInt(null), 0);
      expect(asInt('not a number'), 0);
      expect(asIntOrNull('7'), 7);
      expect(asIntOrNull(null), isNull);
    });

    test('asBool accepts the shapes PHP produces', () {
      expect(asBool(true), isTrue);
      expect(asBool(1), isTrue);
      expect(asBool('1'), isTrue);
      expect(asBool('true'), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool('0'), isFalse);
      expect(asBool(null, true), isTrue);
    });

    test('REGRESSION: a string pipeline_filter no longer throws', () {
      // Laravel's `integer` rule validates a query parameter without casting
      // it, so this came back as "5" and the old `as num?` cast threw —
      // which is exactly what broke the pipeline filter.
      final data = CompanyAnalytics.fromJson(const {
        'pipeline': {
          'total': '3',
          'stages': [
            {'status': 'interview', 'label': 'Interview', 'count': '2', 'percentage': '67'},
          ],
        },
        'pipeline_filter': '5',
        'postings': {'total': '2', 'open': '2'},
      });

      expect(data.pipelineFilter, 5);
      expect(data.pipelineTotal, 3);
      expect(data.pipelineStages.single.count, 2);
      expect(data.pipelineStages.single.percentage, 67);
      expect(data.totalPostings, 2);
    });
  });
}
