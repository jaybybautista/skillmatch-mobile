import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../student/setup/setup_scaffold.dart';
import 'company_setup_review_screen.dart';

/// Steps 1–3 of the company's first-run profile wizard, reached right after
/// [CompanyRegisterForm] submits.
///
/// TODO: not wired to the backend yet — there is no company-profile endpoint
/// to save against, so every step just holds its answers in memory until
/// [CompanySetupReviewScreen] is reached. Follows the same step-by-step shape
/// as the student [SetupWizardScreen] once a real endpoint exists.
class CompanySetupWizardScreen extends StatefulWidget {
  const CompanySetupWizardScreen({super.key, this.companyName});

  /// Prefilled from what was typed on the registration form, if anything.
  final String? companyName;

  @override
  State<CompanySetupWizardScreen> createState() => _CompanySetupWizardScreenState();
}

class _CompanySetupWizardScreenState extends State<CompanySetupWizardScreen> {
  static const _totalSteps = 3;
  int _step = 1;

  // Step 1
  final _description = TextEditingController();

  // Step 2
  final _companyName = TextEditingController();
  final _streetAddress = TextEditingController();
  final _cityMunicipality = TextEditingController();
  final _province = TextEditingController();
  final _websiteUrl = TextEditingController();

  // Step 3
  final _email = TextEditingController();
  final _contactNumber = TextEditingController();

  @override
  void initState() {
    super.initState();
    _companyName.text = widget.companyName ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _description,
      _companyName, _streetAddress, _cityMunicipality, _province, _websiteUrl,
      _email, _contactNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step < _totalSteps) {
      setState(() => _step++);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanySetupReviewScreen(
          description: _description.text.trim(),
          companyName: _companyName.text.trim(),
          streetAddress: _streetAddress.text.trim(),
          cityMunicipality: _cityMunicipality.text.trim(),
          province: _province.text.trim(),
          websiteUrl: _websiteUrl.text.trim(),
          email: _email.text.trim(),
          contactNumber: _contactNumber.text.trim(),
        ),
      ),
    );
  }

  void _back() {
    if (_step == 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: _step,
      totalSteps: _totalSteps,
      stepLabel: _stepLabel,
      title: _stepTitle,
      subtitle: _stepSubtitle,
      onBack: _back,
      onNext: () async => _next(),
      nextLabel: _step == _totalSteps ? 'Review' : 'Next',
      child: _buildStep(),
    );
  }

  String get _stepLabel => switch (_step) {
        1 => 'About the Company',
        2 => 'Company Details',
        _ => 'Contact Information',
      };

  String get _stepTitle => switch (_step) {
        1 => 'About the Company',
        2 => 'Company Details',
        _ => 'Contact Information',
      };

  String get _stepSubtitle => switch (_step) {
        1 => 'Tell students what makes your company a great place to intern.',
        2 => "Where you're located and how applicants can find you online.",
        _ => 'How coordinators and applicants can reach you.',
      };

  Widget _buildStep() => switch (_step) {
        1 => _buildAboutCompany(),
        2 => _buildCompanyDetails(),
        _ => _buildContactInformation(),
      };

  Widget _buildAboutCompany() {
    return _CompanyDescriptionField(controller: _description);
  }

  Widget _buildCompanyDetails() {
    return Column(
      children: [
        SetupField(label: 'Company Name', controller: _companyName),
        const SizedBox(height: 14),
        SetupField(label: 'Street Address', controller: _streetAddress),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SetupField(label: 'City/Municipality', controller: _cityMunicipality)),
            const SizedBox(width: 12),
            Expanded(child: SetupField(label: 'Province', controller: _province)),
          ],
        ),
        const SizedBox(height: 14),
        SetupField(
          label: 'Website URL',
          controller: _websiteUrl,
          keyboardType: TextInputType.url,
          hintText: 'https://example.com',
        ),
      ],
    );
  }

  Widget _buildContactInformation() {
    return Column(
      children: [
        SetupField(
          label: 'Email Address',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        SetupField(
          label: 'Contact Number',
          controller: _contactNumber,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}

/// The company-description textarea with an "AI Help" pill anchored inside
/// its bottom-right corner, matching the web app's ai-suggestion affordance.
///
/// TODO: not wired to a real AI rewrite call — there is no authenticated
/// company session for [AiHelpButton]'s backend request to run under yet.
class _CompanyDescriptionField extends StatelessWidget {
  const _CompanyDescriptionField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F5),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            minLines: 5,
            maxLines: 8,
            style: const TextStyle(color: AppColors.textDark, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: 'Describe your company, culture, mission, and what makes you a great '
                  'employer for interns…',
              hintStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Help is not available for company profiles yet.')),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'AI Help',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}