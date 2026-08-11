import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/editable_profile.dart';
import '../../models/student_profile.dart' show ResumeInfo;
import '../../services/profile_service.dart';
import '../../widgets/primary_button.dart';

/// Edit Profile — personal info plus the resume section, mirroring the web
/// profile page: the same fields, and the same two upload options
/// ("Upload & Auto-Fill" vs "Upload Only") writing to the same tables.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _service = ProfileService();
  final _formKey = GlobalKey<FormState>();

  late Future<EditableProfile> _future = _service.fetchEditableProfile();

  final _name = TextEditingController();
  final _studentNumber = TextEditingController();
  final _contactNumber = TextEditingController();
  final _course = TextEditingController();
  final _address = TextEditingController();
  final _region = TextEditingController();
  final _province = TextEditingController();
  final _city = TextEditingController();
  final _barangay = TextEditingController();

  int? _campusId;
  int? _yearLevel;
  List<CampusOption> _campuses = [];
  ResumeInfo? _resume;

  bool _initialised = false;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _uploadingLabel;

  @override
  void dispose() {
    for (final c in [_name, _studentNumber, _contactNumber, _course, _address, _region, _province, _city, _barangay]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(EditableProfile profile) {
    if (_initialised) return;
    _initialised = true;

    _name.text = profile.name;
    _studentNumber.text = profile.studentNumber ?? '';
    _contactNumber.text = profile.contactNumber ?? '';
    _course.text = profile.course ?? '';
    _address.text = profile.address ?? '';
    _region.text = profile.region ?? '';
    _province.text = profile.province ?? '';
    _city.text = profile.cityMunicipality ?? '';
    _barangay.text = profile.barangay ?? '';
    _campusId = profile.campusId;
    _yearLevel = profile.yearLevel;
    _campuses = profile.campuses;
    _resume = profile.resume;
  }

  String? _blankToNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await _service.updatePersonalInfo(
        name: _name.text.trim(),
        studentNumber: _blankToNull(_studentNumber.text),
        contactNumber: _blankToNull(_contactNumber.text),
        campusId: _campusId,
        course: _blankToNull(_course.text),
        yearLevel: _yearLevel,
        address: _blankToNull(_address.text),
        region: _blankToNull(_region.text),
        province: _blankToNull(_province.text),
        cityMunicipality: _blankToNull(_city.text),
        barangay: _blankToNull(_barangay.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUpload({required bool autofill}) async {
    // The two modes accept different file types server-side, so the picker
    // filters to match rather than letting the upload fail validation.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: autofill ? ['pdf', 'jpg', 'jpeg', 'png'] : ['pdf', 'doc', 'docx'],
    );
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;

    setState(() {
      _isUploading = true;
      _uploadingLabel = autofill ? 'Reading your resume with OCR + AI…' : 'Uploading your resume…';
    });

    try {
      final outcome = autofill
          ? await _service.uploadResumeWithAutofill(path)
          : await _service.uploadResume(path);
      if (!mounted) return;
      setState(() => _resume = outcome.resume ?? _resume);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.message), duration: const Duration(seconds: 5)),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload that file. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingLabel = null;
        });
      }
    }
  }

  Future<void> _removeResume() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove resume?'),
        content: const Text('Your uploaded resume file will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.removeResume();
      if (!mounted) return;
      setState(() => _resume = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resume removed.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<EditableProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message =
                snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Could not load your profile.';
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
              children: [
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _future = _service.fetchEditableProfile()),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          _hydrate(snapshot.data!);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _SectionHeading('Personal Information'),
                const SizedBox(height: 12),
                _Field(label: 'Full Name', controller: _name, isRequired: true),
                _Field(label: 'Student Number', controller: _studentNumber),
                _Field(label: 'Contact Number', controller: _contactNumber, keyboardType: TextInputType.phone),
                _CampusDropdown(
                  campuses: _campuses,
                  value: _campusId,
                  onChanged: (v) => setState(() => _campusId = v),
                ),
                _Field(label: 'Course', controller: _course),
                _YearLevelDropdown(value: _yearLevel, onChanged: (v) => setState(() => _yearLevel = v)),
                const SizedBox(height: 12),
                const _SectionHeading('Address'),
                const SizedBox(height: 12),
                _Field(label: 'Street Address', controller: _address),
                _Field(label: 'Barangay', controller: _barangay),
                _Field(label: 'City / Municipality', controller: _city),
                _Field(label: 'Province', controller: _province),
                _Field(label: 'Region', controller: _region),
                const SizedBox(height: 8),
                PrimaryButton(label: 'Save Changes', isLoading: _isSaving, onPressed: _save),
                const SizedBox(height: 28),
                const _SectionHeading('Resume / CV'),
                const SizedBox(height: 12),
                _ResumeSection(
                  resume: _resume,
                  isUploading: _isUploading,
                  uploadingLabel: _uploadingLabel,
                  onAutofill: () => _pickAndUpload(autofill: true),
                  onUploadOnly: () => _pickAndUpload(autofill: false),
                  onRemove: _removeResume,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResumeSection extends StatelessWidget {
  const _ResumeSection({
    required this.resume,
    required this.isUploading,
    required this.uploadingLabel,
    required this.onAutofill,
    required this.onUploadOnly,
    required this.onRemove,
  });

  final ResumeInfo? resume;
  final bool isUploading;
  final String? uploadingLabel;
  final VoidCallback onAutofill;
  final VoidCallback onUploadOnly;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (resume != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resume!.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Text('Uploaded resume', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: 'Remove',
                  onPressed: isUploading ? null : onRemove,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (isUploading)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    uploadingLabel ?? 'Uploading…',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _UploadOption(
            icon: Icons.auto_fix_high,
            title: 'Upload & Auto-Fill',
            subtitle: 'Reads your resume and fills your Skills, Education & Experience automatically.',
            fileTypes: 'PDF, JPG, PNG — max 8MB',
            isPrimary: true,
            onTap: onAutofill,
          ),
          const SizedBox(height: 12),
          _UploadOption(
            icon: Icons.upload_file_outlined,
            title: 'Upload Only',
            subtitle: 'Just attaches the file to your profile without changing any of your details.',
            fileTypes: 'PDF, DOC, DOCX — max 5MB',
            isPrimary: false,
            onTap: onUploadOnly,
          ),
        ],
      ],
    );
  }
}

class _UploadOption extends StatelessWidget {
  const _UploadOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fileTypes,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String fileTypes;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.chipBackground : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isPrimary ? AppColors.primary : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: isPrimary ? AppColors.primary : AppColors.textMuted),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? AppColors.primary : AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
              const SizedBox(height: 6),
              Text(fileTypes, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.isRequired = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool isRequired;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: isRequired
                ? (value) => (value == null || value.trim().isEmpty) ? '$label is required.' : null
                : null,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampusDropdown extends StatelessWidget {
  const _CampusDropdown({required this.campuses, required this.value, required this.onChanged});

  final List<CampusOption> campuses;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Guard against a campus_id that isn't in the list (shouldn't happen, but
    // a stale id would otherwise throw inside DropdownButtonFormField).
    final safeValue = campuses.any((c) => c.id == value) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CAMPUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: safeValue,
            isExpanded: true,
            items: [
              for (final campus in campuses)
                DropdownMenuItem(value: campus.id, child: Text(campus.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearLevelDropdown extends StatelessWidget {
  const _YearLevelDropdown({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YEAR LEVEL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: (value != null && value! >= 1 && value! <= 5) ? value : null,
            isExpanded: true,
            items: [
              for (var year = 1; year <= 5; year++) DropdownMenuItem(value: year, child: Text('Year $year')),
            ],
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
