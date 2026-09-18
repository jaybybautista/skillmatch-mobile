import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/select_or_other_field.dart';
import '../../../core/api_client.dart';
import '../../../widgets/primary_button.dart';
import '../register_verify_screen.dart';
import 'terms_consent_field.dart';

/// The company sign-up form, reached from [RolePickerScreen] once "Company"
/// has been chosen. Same flow as the web: the form is held by the server,
/// a six-digit code is emailed, and the account exists once the code is
/// entered; the gate then lands the company on its home (pending
/// verification by an admin, like a web sign-up).
class CompanyRegisterForm extends StatefulWidget {
  const CompanyRegisterForm({super.key});

  @override
  State<CompanyRegisterForm> createState() => _CompanyRegisterFormState();
}

class _CompanyRegisterFormState extends State<CompanyRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedIndustry;

  /// Sa server kinukuha, para iisa lang ang listahan ng web at ng app.
  /// May panakip ito pag hindi maabot ang server, kaya may mapipili pa rin
  /// sila kahit mahina ang signal.
  List<String> _industries = kFallbackIndustries;
  String? _errorText;
  bool _acceptedTerms = false;
  String? _termsError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthService>().fetchIndustries().then((industries) {
      if (mounted) setState(() => _industries = industries);
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIndustry == null) {
      setState(() => _errorText = 'Please select your industry.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _termsError = 'Please read and accept the Terms and Conditions, including consent to data collection, to create your account.');
      return;
    }

    setState(() {
      _errorText = null;
      _termsError = null;
      _isLoading = true;
    });

    try {
      final pending = await context.read<AuthService>().registerCompany(
            companyName: _companyNameController.text.trim(),
            industry: _selectedIndustry!,
            address: _addressController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _confirmPasswordController.text,
            acceptedTerms: _acceptedTerms,
          );
      if (!mounted) return;
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
            label: 'Company Name',
            controller: _companyNameController,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Company name is required' : null,
          ),
          const SizedBox(height: 18),
          // May Others dito. May kompanyang wala sa alinman sa mga larangan,
          // kaya kailangan nilang masulat yung sarili nila.
          SelectOrOtherField(
            label: 'Industry',
            value: _selectedIndustry,
            options: _industries,
            hint: 'Select your industry',
            otherLabel: 'Your industry',
            otherHint: 'Type your industry',
            onChanged: (industry) =>
                setState(() => _selectedIndustry = industry),
            validator: (value) =>
                value == null ? 'Please select an industry' : null,
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Address',
            controller: _addressController,
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Address is required' : null,
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Company Email',
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
}