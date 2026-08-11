import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/campus.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../home/home_screen.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, required this.onSwitchToLogin});

  final VoidCallback onSwitchToLogin;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<List<Campus>>? _campusesFuture;
  Campus? _selectedCampus;
  String? _selectedCourse;

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

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await context.read<AuthService>().register(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            course: _selectedCourse!,
            campusId: _selectedCampus!.id,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _confirmPasswordController.text,
          );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
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
                  AppDropdownField<String>(
                    label: 'Course',
                    value: _selectedCourse,
                    items: _selectedCampus?.programs ?? const [],
                    itemLabel: (c) => c,
                    hint: _selectedCampus == null ? 'Select a campus first' : 'Select your course',
                    onChanged: (course) => setState(() => _selectedCourse = course),
                    validator: (value) => value == null ? 'Please select a course' : null,
                  ),
                ],
              );
            },
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
}
