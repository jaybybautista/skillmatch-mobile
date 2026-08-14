import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands raw file bytes to the OS share sheet — the mobile equivalent of a
/// browser's "Save As" for a file the app only has in memory, not on disk.
/// Used by both the requirements list (Download from the kebab menu) and the
/// document viewer (its own Download action) so a template or an uploaded
/// copy can be saved or opened in another app.
Future<void> shareFileBytes(List<int> bytes, String filename) async {
  final file = XFile.fromData(Uint8List.fromList(bytes), name: filename);
  await Share.shareXFiles([file], fileNameOverrides: [filename]);
}
