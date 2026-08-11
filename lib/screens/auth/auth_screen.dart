import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';

/// Combined login / sign-up screen matching the SkillMatch prototype: one
/// logo header, a pill-shaped tab toggle, and a form body that swaps between
/// the login and registration flows.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late int _tabIndex = widget.initialTab;

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
              const SizedBox(height: 16),
              const Text(
                'Hello there, login or register to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
              const SizedBox(height: 24),
              _buildTabToggle(),
              const SizedBox(height: 28),
              if (_tabIndex == 0)
                LoginForm(onSwitchToRegister: () => setState(() => _tabIndex = 1))
              else
                RegisterForm(onSwitchToLogin: () => setState(() => _tabIndex = 0)),
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
          Expanded(child: _tabButton('Log in', 0)),
          Expanded(child: _tabButton('Sign Up', 1)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
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
