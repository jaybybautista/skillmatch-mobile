import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../core/error_message.dart';
import '../../models/company_settings.dart';
import '../../services/company_settings_service.dart';
import '../../widgets/matcha_launcher.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';

/// Company settings — the phone's version of the website's settings page:
/// account credentials, password, notification toggles, and the recruitment
/// preferences that steer matching.
///
/// Everything writes through the shared CompanySettingsService, so a
/// threshold changed here is the same `companies` column the web reads.
class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key, this.service});

  final CompanySettingsService? service;

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  late final CompanySettingsService _service =
      widget.service ?? CompanySettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  Object? _error;
  CompanySettings? _settings;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _workingHoursController = TextEditingController();

  bool _notifyApplications = true;
  bool _notifyAssessments = true;
  bool _notifyPlacements = true;
  int _minMatch = 0;
  String? _workType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactEmailController.dispose();
    _contactNumberController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final settings = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _apply(settings);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _apply(CompanySettings settings) {
    _settings = settings;
    _nameController.text = settings.name;
    _emailController.text = settings.email;

    final prefs = settings.preferences;
    _contactEmailController.text = prefs.contactEmail ?? '';
    _contactNumberController.text = prefs.contactNumber ?? '';
    _workingHoursController.text = prefs.workingHours ?? '';
    _notifyApplications = prefs.notifyApplications;
    _notifyAssessments = prefs.notifyAssessments;
    _notifyPlacements = prefs.notifyPlacements;
    _minMatch = prefs.minMatchThreshold;
    // Only keep a stored work type the backend still offers, so a value
    // dropped from the list can't crash the dropdown.
    _workType = settings.workTypes.contains(prefs.defaultWorkType)
        ? prefs.defaultWorkType
        : null;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isSaving = true);
    try {
      await action();
    } catch (e) {
      _notify(messageForError(e, 'Could not save that.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAccount() => _run(() async {
    final settings = await _service.updateAccount(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _apply(settings));
    _notify('Account credentials updated successfully.');
  });

  Future<void> _savePreferences() => _run(() async {
    final settings = await _service.updatePreferences(
      contactEmail: _contactEmailController.text.trim().isEmpty
          ? null
          : _contactEmailController.text.trim(),
      contactNumber: _contactNumberController.text.trim().isEmpty
          ? null
          : _contactNumberController.text.trim(),
      notifyApplications: _notifyApplications,
      notifyAssessments: _notifyAssessments,
      notifyPlacements: _notifyPlacements,
      minMatchThreshold: _minMatch,
      defaultWorkType: _workType,
      workingHours: _workingHoursController.text.trim().isEmpty
          ? null
          : _workingHoursController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _apply(settings));
    _notify('Company preferences and recruitment settings saved.');
  });

  Future<void> _changePassword() async {
    final result =
        await showDialog<({String current, String next, String confirm})>(
          context: context,
          builder: (_) => const _PasswordDialog(),
        );
    if (result == null) return;

    await _run(() async {
      await _service.updatePassword(
        currentPassword: result.current,
        password: result.next,
        passwordConfirmation: result.confirm,
      );
      _notify('Password updated successfully.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CompanySidebar(current: CompanySidebarItem.settings),
      backgroundColor: AppColors.primaryDark,
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: -1,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CompanyScreenHeader(
                title: 'Settings',
                showMenuButton: true,
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.background,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
          // Same launcher the web keeps on every page.
          const MatchaLauncher(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _settings == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            messageForError(
              _error ?? Exception(),
              'Could not load your settings.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final settings = _settings!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Section(
          title: 'Account',
          icon: Icons.badge_outlined,
          children: [
            _Field(label: 'Display name', controller: _nameController),
            const SizedBox(height: 12),
            _Field(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _SaveButton(
              onPressed: _isSaving ? null : _saveAccount,
              label: 'Save account',
            ),
          ],
        ),

        _Section(
          title: 'Password',
          icon: Icons.lock_outline,
          children: [
            const Text(
              'You will need your current password to set a new one.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            _SaveButton(
              onPressed: _isSaving ? null : _changePassword,
              label: 'Change password',
            ),
          ],
        ),

        _Section(
          title: 'Notifications',
          icon: Icons.notifications_none,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifyApplications,
              onChanged: (v) => setState(() => _notifyApplications = v),
              title: const Text(
                'New applications',
                style: TextStyle(fontSize: 14),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifyAssessments,
              onChanged: (v) => setState(() => _notifyAssessments = v),
              title: const Text(
                'Assessment submissions',
                style: TextStyle(fontSize: 14),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifyPlacements,
              onChanged: (v) => setState(() => _notifyPlacements = v),
              title: const Text(
                'Placement updates',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),

        _Section(
          title: 'Recruitment and AI matching',
          icon: Icons.tune,
          children: [
            const Text(
              'Candidates below this match score are hidden from Browse '
              'candidates until you override it there.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _minMatch.toDouble(),
                    max: 100,
                    divisions: 20,
                    label: '$_minMatch%',
                    onChanged: (v) => setState(() => _minMatch = v.round()),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: Text(
                    '$_minMatch%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(_workType),
              initialValue: _workType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Default work arrangement',
                isDense: true,
              ),
              items: [
                for (final type in settings.workTypes)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (v) => setState(() => _workType = v),
            ),
            const SizedBox(height: 12),
            _Field(label: 'Working hours', controller: _workingHoursController),
            const SizedBox(height: 12),
            _Field(
              label: 'Contact email',
              controller: _contactEmailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Contact number',
              controller: _contactNumberController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _SaveButton(
              onPressed: _isSaving ? null : _savePreferences,
              label: 'Save preferences',
            ),
          ],
        ),

        _Section(
          title: 'Recent sign-ins',
          icon: Icons.security_outlined,
          children: [
            if (settings.loginActivity.isEmpty)
              const Text(
                'No sign-ins recorded yet.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              )
            else
              for (var i = 0; i < settings.loginActivity.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: i == settings.loginActivity.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.loginActivity[i].device,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              settings.loginActivity[i].ipAddress ??
                                  'Unknown address',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        settings.loginActivity[i].atHuman,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

/// Owns its own controllers so they're disposed with the dialog rather than
/// torn down mid-animation by the caller.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _mismatch;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_next.text != _confirm.text) {
      // Caught here rather than on the server: it needs no round trip, and
      // the server's own message names the field rather than the mismatch.
      setState(() => _mismatch = 'The two new passwords do not match.');
      return;
    }

    Navigator.of(
      context,
    ).pop((current: _current.text, next: _next.text, confirm: _confirm.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                errorText: _mismatch,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Update')),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
