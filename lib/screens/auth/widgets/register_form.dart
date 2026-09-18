import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/campus.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/select_or_other_field.dart';
import '../../../widgets/primary_button.dart';
import '../register_verify_screen.dart';
import 'terms_consent_field.dart';

/// The OJT semesters a student can pick at sign-up, as the web lists them.
/// The school year is taken from today's date on the server.
const kSemesters = <({String key, String label})>[
  (key: 'first', label: 'First semester'),
  (key: 'second', label: 'Second semester'),
  (key: 'midyear', label: 'Mid-year'),
];

/// Which semester today falls in, same rule as the server.
String currentSemesterKey([DateTime? now]) {
  final month = (now ?? DateTime.now()).month;
  if (month >= 8) return 'first';
  if (month <= 5) return 'second';
  return 'midyear';
}

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, required this.onSwitchToLogin});

  final VoidCallback onSwitchToLogin;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<List<Campus>>? _campusesFuture;
  Campus? _selectedCampus;
  String? _selectedCourse;
  String _semester = currentSemesterKey();
  bool _acceptedTerms = false;
  String? _termsError;

  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _campusesFuture = context.read<AuthService>().fetchCampuses();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCampus == null || _selectedCourse == null) {
      setState(() => _errorText = 'Please select your campus and course.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _termsError = 'Please read and accept the Terms and Conditions, including consent to data collection, to create your account.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _termsError = null;
    });

    try {
      final pending = await context.read<AuthService>().register(
            firstName: _firstNameController.text.trim(),
            middleName: _middleNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            course: _selectedCourse!,
            campusId: _selectedCampus!.id,
            semester: _semester,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _confirmPasswordController.text,
            acceptedTerms: _acceptedTerms,
          );

      if (!mounted) return;
      // Like the web: the account exists only after the emailed code. The
      // verify screen stores the session and unwinds to the gate, which
      // then decides between the setup wizard and Home.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegisterVerifyScreen(email: pending.email, message: pending.message),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorText = e.fieldError('terms') ?? e.message);
    } catch (_) {
      setState(() => _errorText = 'Could not reach the server. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Firstname',
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'First name is required' : null,
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Middle name (optional)',
            controller: _middleNameController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Lastname',
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Last name is required' : null,
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Campus>>(
            future: _campusesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const Text(
                  'Could not load campuses. Pull to refresh or try again shortly.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                );
              }

              final campuses = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownField<Campus>(
                    label: 'Campus',
                    value: _selectedCampus,
                    items: campuses,
                    itemLabel: (c) => c.name,
                    hint: 'Select your campus',
                    onChanged: (campus) => setState(() {
                      _selectedCampus = campus;
                      _selectedCourse = null;
                    }),
                    validator: (value) => value == null ? 'Please select a campus' : null,
                  ),
                  const SizedBox(height: 18),
                  // May Others dito. Hindi lahat ng programa ay nasa listahan
                  // ng campus, kaya kailangan nilang masulat yung sarili nila
                  // - kung hindi, hindi sila makakapagparehistro.
                  SelectOrOtherField(
                    label: 'Course',
                    value: _selectedCourse,
                    options: _selectedCampus?.programs ?? const [],
                    enabled: _selectedCampus != null,
                    hint: 'Select your course',
                    emptyHint: 'Select a campus first',
                    otherLabel: 'Your course',
                    otherHint: 'Type your course',
                    onChanged: (course) =>
                        setState(() => _selectedCourse = course),
                    validator: (value) =>
                        value == null ? 'Please select a course' : null,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          // Semester ng OJT; ang school year ay kusang kinukuha ng server
          // mula sa petsa (SY na kasalukuyan), gaya ng web.
          AppDropdownField<String>(
            label: 'Semester (SY ${_schoolYearLabel()})',
            value: _semester,
            items: [for (final s in kSemesters) s.key],
            itemLabel: (key) => kSemesters.firstWhere((s) => s.key == key).label,
            onChanged: (value) => setState(() => _semester = value ?? _semester),
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email is required';
              if (!value.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Confirm Password',
            controller: _confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TermsConsentField(
            value: _acceptedTerms,
            errorText: _termsError,
            onChanged: (v) => setState(() {
              _acceptedTerms = v;
              if (v) _termsError = null;
            }),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          PrimaryButton(label: 'Create Account', isLoading: _isLoading, onPressed: _submit),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// "2026-2027": a school year starts in August, same as the server.
  String _schoolYearLabel() {
    final now = DateTime.now();
    final start = now.month >= 8 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }
}
