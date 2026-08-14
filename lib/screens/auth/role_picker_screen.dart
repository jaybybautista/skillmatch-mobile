import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import 'register_screen.dart';

/// The two account types the SkillMatch platform recognises at sign-up. These
/// map to `users.role` on the backend: the web register page offers the same
/// pair (a "Student" tab and a "Company" tab linking to register.company).
enum SignUpRole {
  student('Student', Icons.school),
  company('Company', Icons.apartment);

  const SignUpRole(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Shown every time the student opens registration, before any form: pick who
/// you are, then continue.
///
/// Only [SignUpRole.student] continues into the app. The mobile app has no
/// company screens at all — a company account created here would land on a
/// student dashboard — so choosing Company explains that company sign-up is
/// done on the website, which is the same place their dashboard lives.
class RolePickerScreen extends StatefulWidget {
  const RolePickerScreen({super.key});

  @override
  State<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends State<RolePickerScreen> {
  SignUpRole _selected = SignUpRole.student;

  void _continue() {
    if (_selected == SignUpRole.student) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Company sign-up'),
        content: Text(
          'The SkillMatch app is built for students, so company accounts are '
          'created on the website instead — that is also where you post '
          'internships and review applicants.\n\nVisit ${ApiConfig.siteUrl}/register/company '
          'on a browser to get started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BackButton(
                color: AppColors.textDark,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            // The logo block takes whatever space the sheet leaves, so the
            // sheet keeps its natural height on both short and tall phones.
            Expanded(
              child: Center(
                // The sheet takes the height it needs first; the logo scales
                // down into whatever is left, so a short screen shrinks the
                // branding instead of overflowing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo.png', height: 120),
                      const SizedBox(height: 16),
                      Image.asset('assets/letter-skillmatch.png', height: 52),
                    ],
                  ),
                ),
              ),
            ),
            _RoleSheet(
              selected: _selected,
              onSelected: (role) => setState(() => _selected = role),
              onContinue: _continue,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSheet extends StatelessWidget {
  const _RoleSheet({
    required this.selected,
    required this.onSelected,
    required this.onContinue,
  });

  final SignUpRole selected;
  final ValueChanged<SignUpRole> onSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.account_box, size: 44, color: AppColors.primary),
          const SizedBox(height: 14),
          const Text(
            'Describe Your Role',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final role in SignUpRole.values) ...[
                if (role != SignUpRole.values.first) const SizedBox(width: 14),
                Expanded(
                  child: _RoleCard(
                    role: role,
                    isSelected: role == selected,
                    onTap: () => onSelected(role),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.isSelected, required this.onTap});

  final SignUpRole role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? const Color(0xFFF7F9FE) : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.chipBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(role.icon, size: 30, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  role.label,
                  style: const TextStyle(fontSize: 17, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
