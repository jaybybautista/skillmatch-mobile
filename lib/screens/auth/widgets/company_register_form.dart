import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../company/company_setup_wizard_screen.dart';

/// Industries offered in the [AppDropdownField] below. The web app's
/// register.company page sources this list from the backend; until a mobile
/// company-registration endpoint exists, it's kept as a fixed list here.
const List<String> _kIndustries = [
  'Technology',
  'Manufacturing',
  'Healthcare',
  'Retail',
  'Finance',
  'Education',
  'Construction',
  'Hospitality',
  'Agriculture',
  'Transportation',
  'Other',
];

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
  String? _errorText;

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
          AppDropdownField<String>(
            label: 'Industry',
            value: _selectedIndustry,
            items: _kIndustries,
            itemLabel: (industry) => industry,
            hint: 'Select your industry',
            onChanged: (industry) => setState(() => _selectedIndustry = industry),
            validator: (value) => value == null ? 'Please select an industry' : null,
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