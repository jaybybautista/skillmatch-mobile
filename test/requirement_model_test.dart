import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/requirement.dart';

void main() {
  group('RequirementSubmissionInfo', () {
    test('no submission yet parses as not started', () {
      final submission = RequirementSubmissionInfo.fromJson(const {});
      expect(submission.hasUpload, isFalse);
      expect(submission.status, 'draft');
      expect(submission.isSubmitted, isFalse);
    });

    test('a draft upload parses its file info', () {
      final submission = RequirementSubmissionInfo.fromJson(const {
        'has_upload': true,
        'status': 'draft',
        'original_filename': 'my-form.pdf',
        'file_size': 46080,
        'readable_size': '45 KB',
        'file_kind': 'pdf',
        'submitted_at': null,
        'updated_at_human': '2 hours ago',
      });

      expect(submission.hasUpload, isTrue);
      expect(submission.isSubmitted, isFalse);
      expect(submission.originalFilename, 'my-form.pdf');
      expect(submission.readableSize, '45 KB');
    });

    test('a submitted upload reports isSubmitted', () {
      final submission = RequirementSubmissionInfo.fromJson(const {
        'has_upload': true,
        'status': 'submitted',
        'submitted_at': '2026-08-14T10:00:00+00:00',
      });

      expect(submission.isSubmitted, isTrue);
    });
  });

  group('RequirementItem', () {
    test('parses a coordinator-published form with no submission yet', () {
      final item = RequirementItem.fromJson(const {
        'id': 1,
        'title': 'Application for Internship',
        'description': 'Fill this out before your first day.',
        'file_kind': 'doc',
        'original_filename': 'Application Internship.docx',
        'file_size': 46080,
        'readable_size': '45 KB',
        'has_template': true,
        'updated_at_human': '3 hours ago',
        'submission': {'has_upload': false, 'status': 'draft'},
      });

      expect(item.id, 1);
      expect(item.title, 'Application for Internship');
      expect(item.hasTemplate, isTrue);
      expect(item.submission.hasUpload, isFalse);
    });

    test('missing submission key falls back to not-started', () {
      final item = RequirementItem.fromJson(const {
        'id': 2,
        'title': 'MOA Template',
        'file_kind': 'pdf',
        'file_size': 1258291,
        'readable_size': '1.2 MB',
        'has_template': true,
      });

      expect(item.submission.hasUpload, isFalse);
      expect(item.submission.isSubmitted, isFalse);
    });
  });
}
