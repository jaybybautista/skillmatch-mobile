/// The student's own working copy of one requirement — mirrors a
/// `requirement_submissions` row, the same one the coordinator sees on the
/// web submissions grid.
class RequirementSubmissionInfo {
  RequirementSubmissionInfo({
    required this.hasUpload,
    required this.status,
    this.originalFilename,
    this.fileSize,
    this.readableSize,
    this.fileKind,
    this.submittedAt,
    this.updatedAtHuman,
  });

  final bool hasUpload;
  final String status; // draft | submitted
  final String? originalFilename;
  final int? fileSize;
  final String? readableSize;
  final String? fileKind;
  final String? submittedAt;
  final String? updatedAtHuman;

  bool get isSubmitted => status == 'submitted';

  factory RequirementSubmissionInfo.fromJson(Map<String, dynamic> json) {
    return RequirementSubmissionInfo(
      hasUpload: json['has_upload'] as bool? ?? false,
      status: json['status'] as String? ?? 'draft',
      originalFilename: json['original_filename'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      readableSize: json['readable_size'] as String?,
      fileKind: json['file_kind'] as String?,
      submittedAt: json['submitted_at'] as String?,
      updatedAtHuman: json['updated_at_human'] as String?,
    );
  }
}

/// One coordinator-published form — a `requirements` row — plus the current
/// student's own submission status for it.
class RequirementItem {
  RequirementItem({
    required this.id,
    required this.title,
    this.description,
    required this.fileKind,
    this.originalFilename,
    required this.fileSize,
    required this.readableSize,
    required this.hasTemplate,
    this.updatedAtHuman,
    required this.submission,
  });

  final int id;
  final String title;
  final String? description;
  final String fileKind;
  final String? originalFilename;
  final int fileSize;
  final String readableSize;
  final bool hasTemplate;
  final String? updatedAtHuman;
  final RequirementSubmissionInfo submission;

  factory RequirementItem.fromJson(Map<String, dynamic> json) {
    return RequirementItem(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Requirement',
      description: json['description'] as String?,
      fileKind: json['file_kind'] as String? ?? 'file',
      originalFilename: json['original_filename'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      readableSize: json['readable_size'] as String? ?? '0 B',
      hasTemplate: json['has_template'] as bool? ?? false,
      updatedAtHuman: json['updated_at_human'] as String?,
      submission: RequirementSubmissionInfo.fromJson(
        json['submission'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// How the viewer should render a previewed file — mirrors what
/// `DocumentPreviewService::resolve()` decides on the backend.
enum PreviewKind { pdf, image, none }

class RequirementPreview {
  RequirementPreview({required this.kind, this.bytes, this.message});

  final PreviewKind kind;
  final List<int>? bytes;
  final String? message;
}

class RequirementFile {
  RequirementFile({required this.bytes, required this.filename, this.mimeType});

  final List<int> bytes;
  final String filename;
  final String? mimeType;
}
