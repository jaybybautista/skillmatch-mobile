import '../core/api_client.dart';
import '../models/requirement.dart';

/// Talks to Api\RequirementController, which reads and writes the same
/// `requirements`/`requirement_submissions` rows and the same files on the
/// `public` disk as the web's Student\StudentRequirementController — an
/// upload or a submit from the phone is exactly what the coordinator sees.
class RequirementService {
  final ApiClient _client = ApiClient.instance;

  Future<List<RequirementItem>> fetchAll() async {
    final response = await _client.get('/student/requirements', authenticated: true);
    return (response['requirements'] as List? ?? const [])
        .map((e) => RequirementItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The coordinator's original form, rendered the way the web's own viewer
  /// shows it — already converted to PDF server-side when it isn't one.
  Future<RequirementPreview> previewTemplate(int requirementId) =>
      _preview('/student/requirements/$requirementId/preview');

  /// The student's own uploaded copy.
  Future<RequirementPreview> previewUpload(int requirementId) =>
      _preview('/student/requirements/$requirementId/my-copy/preview');

  Future<RequirementPreview> _preview(String path) async {
    try {
      final response = await _client.getBytes(path, authenticated: true);
      final contentType = response.headers['content-type'] ?? '';
      final kind = contentType.contains('pdf')
          ? PreviewKind.pdf
          : contentType.startsWith('image/')
              ? PreviewKind.image
              : PreviewKind.none;
      return RequirementPreview(kind: kind, bytes: response.bodyBytes);
    } on ApiException catch (e) {
      return RequirementPreview(kind: PreviewKind.none, message: e.message);
    }
  }

  /// The blank master copy, exactly as the coordinator published it.
  Future<List<int>> downloadTemplate(int requirementId) async {
    final response = await _client.getBytes('/student/requirements/$requirementId/download', authenticated: true);
    return response.bodyBytes;
  }

  /// Whatever the student uploaded for this requirement.
  Future<List<int>> downloadUpload(int requirementId) async {
    final response =
        await _client.getBytes('/student/requirements/$requirementId/my-copy/download', authenticated: true);
    return response.bodyBytes;
  }

  /// Upload a copy filled in outside the app. Replacing an existing upload
  /// resets it back to draft, same as the web.
  Future<void> upload(int requirementId, String filePath) async {
    await _client.postMultipart(
      '/student/requirements/$requirementId/upload',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'document',
      authenticated: true,
    );
  }

  Future<void> removeUpload(int requirementId) async {
    await _client.delete('/student/requirements/$requirementId/upload', authenticated: true);
  }

  Future<void> submit(int requirementId) async {
    await _client.post('/student/requirements/$requirementId/submit', const {}, authenticated: true);
  }

  Future<void> unsubmit(int requirementId) async {
    await _client.post('/student/requirements/$requirementId/unsubmit', const {}, authenticated: true);
  }
}
