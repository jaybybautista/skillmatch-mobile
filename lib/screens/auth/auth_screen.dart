import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'role_picker_screen.dart';
import 'widgets/login_form.dart';

/// Login screen matching the SkillMatch prototype: one logo header, a
/// pill-shaped tab toggle, and the login form.
///
/// "Sign Up" is not a second form here — it opens [RolePickerScreen], so the
/// role question is asked every single time registration is entered, from
/// either the toggle or the form's "Create one" link.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  void _openRegistration() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RolePickerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Image.asset('assets/logo.png', height: 90),
              const SizedBox(height: 12),
              Image.asset('assets/letter-skillmatch.png', height: 40),
              const Text(
                'Hello there, login or register to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildTabToggle(),
              const SizedBox(height: 28),
              LoginForm(onSwitchToRegister: _openRegistration),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // "Log in" stays selected: Sign Up pushes the role picker rather
          // than swapping this screen's body, so there is no second tab state.
          Expanded(child: _tabButton('Log in', selected: true, onTap: null)),
          Expanded(
            child: _tabButton(
              'Sign Up',
              selected: false,
              onTap: _openRegistration,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    String label, {
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
