import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/error_message.dart';
import '../../models/company_profile.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';

/// Editing the company's own profile — the phone's version of the website's
/// "Edit profile" mode.
///
/// Saves through PUT /api/company/profile, which validates with
/// CompanyProfileService::rules(): the identical fields and limits the web
/// form posts, writing the identical `companies` row.
class EditCompanyProfileScreen extends StatefulWidget {
  const EditCompanyProfileScreen({
    super.key,
    required this.profile,
    this.service,
  });

  final CompanyProfile profile;
  final CompanyService? service;

  @override
  State<EditCompanyProfileScreen> createState() =>
      _EditCompanyProfileScreenState();
}

class _EditCompanyProfileScreenState extends State<EditCompanyProfileScreen> {
  /// The same fifteen options the website's industry dropdown offers.
  static const industries = [
    'Information Technology',
    'Software Development',
    'BPO / Call Center',
    'Manufacturing',
    'Healthcare',
    'Finance & Banking',
    'Education',
    'Retail & E-Commerce',
    'Engineering',
    'Media & Communications',
    'Food & Beverage',
    'Government',
    'Non-Profit / NGO',
    'Construction',
    'Other',
  ];

  late final CompanyService _service = widget.service ?? CompanyService();
  final _formKey = GlobalKey<FormState>();

  late final _companyName = TextEditingController(
    text: widget.profile.companyName,
  );
  late final _description = TextEditingController(
    text: widget.profile.description ?? '',
  );
  late final _address = TextEditingController(
    text: widget.profile.address ?? '',
  );
  late final _region = TextEditingController(text: widget.profile.region ?? '');
  late final _province = TextEditingController(
    text: widget.profile.province ?? '',
  );
  late final _city = TextEditingController(text: widget.profile.city ?? '');
  late final _barangay = TextEditingController(
    text: widget.profile.barangay ?? '',
  );
  late final _website = TextEditingController(
    text: widget.profile.website ?? '',
  );
  late final _contactEmail = TextEditingController(
    text: widget.profile.contactEmail ?? '',
  );
  late final _contactNumber = TextEditingController(
    text: widget.profile.contactNumber ?? '',
  );

  late String? _industry = _initialIndustry();

  bool _isSaving = false;

  /// Keeps an industry the account already has even when it isn't one of the
  /// listed options — an older value shouldn't be silently wiped by opening
  /// this screen.
  String? _initialIndustry() {
    final current = widget.profile.industry?.trim();
    if (current == null || current.isEmpty) return null;
    return current;
  }

  List<String> get _industryOptions {
    final current = _industry;
    if (current == null || industries.contains(current)) return industries;
    return [current, ...industries];
  }

  @override
  void dispose() {
    for (final c in [
      _companyName,
      _description,
      _address,
      _region,
      _province,
      _city,
      _barangay,
      _website,
      _contactEmail,
      _contactNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final saved = await _service.updateProfile(
        companyName: _companyName.text.trim(),
        // Sent even when blank, so clearing a field actually clears it.
        // Laravel turns an empty string into null before validating, which is
        // what lets `nullable|url` accept a cleared website.
        industry: _industry ?? '',
        description: _description.text.trim(),
        address: _address.text.trim(),
        region: _region.text.trim(),
        province: _province.text.trim(),
        city: _city.text.trim(),
        barangay: _barangay.text.trim(),
        website: _website.text.trim(),
        contactEmail: _contactEmail.text.trim(),
        contactNumber: _contactNumber.text.trim(),
      );

      if (!mounted) return;
      navigator.pop(saved);
      messenger.showSnackBar(
        const SnackBar(content: Text('Company profile updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _notify(
        messageForError(
          e,
          'Could not save your profile. Check your connection and try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: 'Edit Profile',
            onBack: () {
              if (!_isSaving) Navigator.of(context).maybePop();
            },
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                children: [
                  _section('Company information', [
                    _field(
                      label: 'Company name *',
                      controller: _companyName,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'A company name is required.'
                          : null,
                    ),
                    _industryField(),
                    _field(
                      label: 'Company description',
                      controller: _description,
                      hint:
                          'Describe your company, culture, mission, and what '
                          'makes you a great employer for interns…',
                      maxLines: 6,
                      maxLength: 3000,
                    ),
                    _field(
                      label: 'Website URL',
                      controller: _website,
                      hint: 'https://yourcompany.com',
                      keyboardType: TextInputType.url,
                      validator: _validateWebsite,
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _section('Address', [
                    _field(
                      label: 'Street address',
                      controller: _address,
                      hint: 'e.g. 123 Rizal Avenue',
                    ),
                    _field(label: 'Region', controller: _region),
                    _field(label: 'Province', controller: _province),
                    _field(label: 'City / Municipality', controller: _city),
                    _field(label: 'Barangay', controller: _barangay),
                  ]),
                  const SizedBox(height: 18),
                  _section('Contact information', [
                    _field(
                      label: 'Contact email',
                      controller: _contactEmail,
                      hint: 'e.g. hr@yourcompany.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    _field(
                      label: 'Contact number',
                      controller: _contactNumber,
                      hint: 'e.g. +63 912 345 6789',
                      keyboardType: TextInputType.phone,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save changes'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mirrors the server's `nullable|url`: blank is fine, anything else has to
  /// be a real absolute URL.
  String? _validateWebsite(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a full URL, including https://';
    }
    return null;
  }

  /// Mirrors the server's `nullable|email`.
  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return looksLikeEmail ? null : 'Enter a valid email address.';
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.title(fontSize: 15.5, color: AppColors.textDark),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator,
        enabled: !_isSaving,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _industryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String?>(
        initialValue: _industry,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Industry'),
        items: [
          const DropdownMenuItem<String?>(child: Text('Select industry…')),
          for (final option in _industryOptions)
            DropdownMenuItem<String?>(value: option, child: Text(option)),
        ],
        onChanged: _isSaving
            ? null
            : (value) => setState(() => _industry = value),
      ),
    );
  }
}
