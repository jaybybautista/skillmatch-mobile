import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_storage.dart';

const _requestTimeout = Duration(seconds: 12);

/// AI Help and resume import hit a Groq call (and, for import, server-side
/// OCR) that can legitimately take much longer than a normal API round trip.
/// The backend's own Groq timeout is 45s, so this leaves headroom for OCR
/// (Tesseract/PdfParser) to run first.
const _longRequestTimeout = Duration(seconds: 90);

/// Thrown whenever the API responds with a non-2xx status.
///
/// [errors] mirrors Laravel's validation error bag (field name -> messages),
/// so screens can surface field-specific messages when present.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  String? fieldError(String field) => errors?[field]?.first;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, String>> _headers({bool authenticated = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await TokenStorage.instance.readToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = false}) async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: await _headers(authenticated: authenticated))
        .timeout(_requestTimeout, onTimeout: _throwTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout, onTimeout: _throwTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) async {
    final response = await http
        .put(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout, onTimeout: _throwTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path, {bool authenticated = false}) async {
    final response = await http
        .delete(Uri.parse('${ApiConfig.baseUrl}$path'), headers: await _headers(authenticated: authenticated))
        .timeout(_requestTimeout, onTimeout: _throwTimeout);
    return _decode(response);
  }

  /// Same as [post], but with a much longer timeout for AI calls.
  Future<Map<String, dynamic>> postLong(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(body),
        )
        .timeout(_longRequestTimeout, onTimeout: _throwTimeout);
    return _decode(response);
  }

  /// Multipart file upload (resume import), with the same long timeout —
  /// OCR + AI parsing on the server can take a while for a scanned file.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    String? filePath,
    String? fileFieldName,
    bool authenticated = false,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'));
    final headers = await _headers(authenticated: authenticated);
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.fields.addAll(fields);

    if (filePath != null && fileFieldName != null) {
      request.files.add(await http.MultipartFile.fromPath(fileFieldName, filePath));
    }

    final streamed = await request.send().timeout(_longRequestTimeout, onTimeout: _throwTimeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Never _throwTimeout() {
    throw ApiException('The server took too long to respond. Please try again.');
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // Non-JSON response (e.g. a raw 500 HTML page) — fall through to the
        // generic error message below.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    Map<String, List<String>>? errors;
    if (data['errors'] is Map) {
      errors = (data['errors'] as Map).map(
        (key, value) => MapEntry(key.toString(), List<String>.from(value as List)),
      );
    }

    String? firstFieldError;
    if (errors != null && errors.isNotEmpty) {
      final firstList = errors.values.first;
      if (firstList.isNotEmpty) firstFieldError = firstList.first;
    }

    final message = data['message'] as String? ?? firstFieldError ?? 'Something went wrong. Please try again.';

    throw ApiException(message, statusCode: response.statusCode, errors: errors);
  }
}
