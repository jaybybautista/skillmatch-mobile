import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'widgets/register_form.dart';

/// The student sign-up form on its own screen, reached from
/// [RolePickerScreen] once "Student" has been chosen.
///
/// "Log in instead" pops all the way back rather than pushing a new login
/// screen, so the picker never stacks up behind a half-finished sign-up.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Create your account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Signing up as a Student',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              RegisterForm(
                onSwitchToLogin: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
