import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/select_or_other_field.dart';
import '../../../widgets/primary_button.dart';
import '../../company/company_setup_wizard_screen.dart';


/// The company sign-up form, reached from [RolePickerScreen] once "Company"
/// has been chosen.
///
/// TODO: not wired to the backend yet — there is no company-registration
/// endpoint in [AuthService] and no company dashboard for a new account to
/// land on. [_submit] only validates the form and moves into the (also
/// locally-held) [CompanySetupWizardScreen] for now; hook up real API calls
/// once those exist.
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIndustry == null) {
      setState(() => _errorText = 'Please select your industry.');
      return;
    }

    setState(() => _errorText = null);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanySetupWizardScreen(companyName: _companyNameController.text.trim()),
      ),
    );
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
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          PrimaryButton(label: 'Create Account', onPressed: _submit),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}