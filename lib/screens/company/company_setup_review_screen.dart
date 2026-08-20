import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/circle_back_button.dart';
import '../auth/auth_screen.dart';

/// The last stop of the company wizard: everything just typed, laid out for
/// a final check before "submitting" the profile.
///
/// TODO: not wired to the backend yet — there is no company-profile endpoint
/// to save against, so "Save and Continue" only shows a confirmation and
/// returns to the login screen. See [CompanySetupWizardScreen].
class CompanySetupReviewScreen extends StatelessWidget {
  const CompanySetupReviewScreen({
    super.key,
    required this.description,
    required this.companyName,
    required this.streetAddress,
    required this.cityMunicipality,
    required this.province,
    required this.websiteUrl,
    required this.email,
    required this.contactNumber,
  });

  final String description;
  final String companyName;
  final String streetAddress;
  final String cityMunicipality;
  final String province;
  final String websiteUrl;
  final String email;
  final String contactNumber;

  void _save(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SubmittedForReviewDialog(
        onDone: () {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 18),
                child: Row(
                  children: [
                    CircleBackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      filled: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review your profile',
                            style: AppFonts.title(
                              fontSize: 19,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Check the details before saving.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              children: [
                _Card(
                  title: 'About the Company',
                  onEdit: () => Navigator.of(context).maybePop(),
                  child: Text(
                    description.isEmpty ? 'Not provided' : description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: description.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textDark,
                    ),
                  ),
                ),
                _Section(
                  title: 'Company Details',
                  onEdit: () => Navigator.of(context).maybePop(),
                  rows: [
                    ('Company Name', companyName),
                    ('Street Address', streetAddress),
                    ('City/Municipality', cityMunicipality),
                    ('Province', province),
                    ('Website URL', websiteUrl),
                  ],
                ),
                _Section(
                  title: 'Contact Information',
                  onEdit: () => Navigator.of(context).maybePop(),
                  rows: [
                    ('Email Address', email),
                    ('Contact Number', contactNumber),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: () => _save(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save and Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly confirmation shown once the company profile is submitted —
/// echoes the amber "reviewed before going live" notice from registration
/// rather than a plain system [AlertDialog].
class _SubmittedForReviewDialog extends StatelessWidget {
  const _SubmittedForReviewDialog({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warningBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.warningBorder, width: 1.5),
              ),
              child: const Icon(
                Icons.pending_actions_rounded,
                color: AppColors.warning,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Account submitted for review',
              textAlign: TextAlign.center,
              style: AppFonts.title(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              "Company accounts are reviewed before going live. You'll be able to post "
              'internships once a coordinator approves your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.onEdit, required this.child});

  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppFonts.title(fontSize: 15)),
              InkWell(
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  final String title;
  final VoidCallback onEdit;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final present = rows.where((r) => r.$2.trim().isNotEmpty).toList();

    return _Card(
      title: title,
      onEdit: onEdit,
      child: present.isEmpty
          ? const Text(
              'Not provided',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          : Column(
              children: [
                for (final row in present)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            row.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.$2,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
