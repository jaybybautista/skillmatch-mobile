import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// "Retake open" means a fresh attempt has been handed to the student and they
/// have not answered it yet.
///
/// This is the standing half of the Retake confirmation: the snackbar says
/// the tap registered, this says the attempt is genuinely waiting. It
/// disappears on its own once the student submits again, and the web shows
/// the same tag driven by the same server-side rule.
class RetakeOpenTag extends StatelessWidget {
  const RetakeOpenTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.refresh, size: 11, color: AppColors.warning),
          SizedBox(width: 4),
          Text(
            'Retake open',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
