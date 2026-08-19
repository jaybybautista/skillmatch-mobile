import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/circle_back_button.dart';
import 'widgets/company_register_form.dart';

/// The company sign-up form on its own screen, reached from
/// [RolePickerScreen] once "Company" has been chosen.
class CompanyRegisterScreen extends StatelessWidget {
  const CompanyRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: const Center(child: CircleBackButton()),
        title: Text('Create your account', style: AppFonts.title()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Signing up as a Company',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const _ReviewNoticeBanner(),
              const SizedBox(height: 20),
              const CompanyRegisterForm(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells the company up front that the account won't post internships
/// immediately — it goes through coordinator review first.
class _ReviewNoticeBanner extends StatelessWidget {
  const _ReviewNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppColors.warning, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Company accounts are reviewed before going live. You'll be able to "
              'post internships once a coordinator approves your account.',
              style: TextStyle(color: AppColors.warning, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}