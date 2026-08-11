import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../services/profile_service.dart';

/// Picks an image and uploads it as the student's profile photo, writing the
/// same users.profile_picture value the web does. Returns true when the photo
/// actually changed, so callers can refresh.
///
/// Shared by the avatar badge and the full-screen viewer's "Change Photo".
Future<bool> pickAndUploadProfilePhoto(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
  );

  final path = result?.files.singleOrNull?.path;
  if (path == null || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Uploading photo…'), duration: Duration(seconds: 2)),
  );

  try {
    await ProfileService().updatePhoto(path);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    return true;
  } on ApiException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Could not upload that photo. Please try again.')));
  }

  return false;
}
