import 'api_config.dart';

/// Turns the relative paths the messaging API sends (`/storage/...`,
/// `/SkillMatch/SkillMatch/public/storage/...`) into something
/// `Image.network` can load.
///
/// The backend deliberately strips its own host from attachment and avatar
/// links (see `MessagingService::relativeUrl`) because the same payload is
/// broadcast to browsers on different origins. The path it keeps already
/// includes the Apache sub-path when the request came through Apache, so the
/// right prefix here is the bare scheme + host, never [ApiConfig.siteUrl].
String? resolveServerUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  final site = Uri.parse(ApiConfig.siteUrl);
  final origin = site.hasPort
      ? '${site.scheme}://${site.host}:${site.port}'
      : '${site.scheme}://${site.host}';

  return url.startsWith('/') ? '$origin$url' : '$origin/$url';
}
