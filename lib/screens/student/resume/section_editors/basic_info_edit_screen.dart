import 'package:flutter/material.dart';

import '../../../../core/api_client.dart';
import '../../../../core/app_theme.dart';
import '../../../../models/resume.dart';
import '../../../../services/resume_service.dart';
import '../../../../widgets/primary_button.dart';

class BasicInfoEditScreen extends StatefulWidget {
  const BasicInfoEditScreen({super.key, required this.section});

  final ResumeSection section;

  @override
  State<BasicInfoEditScreen> createState() => _BasicInfoEditScreenState();
}

class _BasicInfoEditScreenState extends State<BasicInfoEditScreen> {
  final _service = ResumeService();
  late final _fullNameController = TextEditingController(text: widget.section.basicInfo?.fullName ?? '');
  late final _addressController = TextEditingController(text: widget.section.basicInfo?.address ?? '');
  late final _zipController = TextEditingController(text: widget.section.basicInfo?.zipCode ?? '');
  late final _phoneController = TextEditingController(text: widget.section.basicInfo?.phoneNumber ?? '');
  late final _emailController = TextEditingController(text: widget.section.basicInfo?.email ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _service.updateBasicInfo(
        widget.section.id,
        fullName: _fullNameController.text,
        address: _addressController.text,
        zipCode: _zipController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Basic info saved.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(controller: controller, keyboardType: keyboardType),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Basic Info', style: AppFonts.title(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline, size: 40, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile photo upload is coming soon.')),
                  ),
                  child: const Text('Add or change profile photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _field('Full Name', _fullNameController),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _field('Address', _addressController)),
              const SizedBox(width: 12),
              Expanded(child: _field('Zip Code', _zipController)),
            ],
          ),
          const SizedBox(height: 16),
          _field('Phone Number', _phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _field('Email Address', _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', isLoading: _isSaving, onPressed: _save),
        ],
      ),
    );
  }
}
