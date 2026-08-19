import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/public_profile.dart';
import '../../../services/public_profile_service.dart';
import '../../../widgets/public_profile_header.dart';
import 'profile_screen.dart';

/// A coordinator's public profile — the mobile twin of
/// Student\StudentPeerController::showCoordinator / student.coordinators.show.
class CoordinatorPublicProfileScreen extends StatefulWidget {
  const CoordinatorPublicProfileScreen({super.key, required this.coordinatorId, this.service});

  final int coordinatorId;
  final PublicProfileService? service;

  @override
  State<CoordinatorPublicProfileScreen> createState() => _CoordinatorPublicProfileScreenState();
}

class _CoordinatorPublicProfileScreenState extends State<CoordinatorPublicProfileScreen> {
  late final PublicProfileService _service = widget.service ?? PublicProfileService();
  late Future<CoordinatorPublicProfile> _future = _service.fetchCoordinator(widget.coordinatorId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Coordinator Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<CoordinatorPublicProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Could not load this profile. Please check your connection.';

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
              children: [
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _future = _service.fetchCoordinator(widget.coordinatorId)),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          final profile = snapshot.data!;

          if (profile.isSelf) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            });
            return const Center(child: CircularProgressIndicator());
          }

          final name = profile.name ?? 'Coordinator';
          final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
          final initials = parts.length >= 2
              ? (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase()
              : (parts.isNotEmpty ? parts.first.substring(0, 1).toUpperCase() : '?');

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PublicProfileHeader(
                name: name,
                initials: initials,
                avatarUrl: profile.avatarUrl,
                coverUrl: profile.coverUrl,
                subtitle: profile.department ?? 'OJT Coordinator',
                chips: [
                  if (profile.campus != null)
                    ProfileMetaChip(icon: Icons.apartment_outlined, label: profile.campus!),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ProfileSectionCard(
                  icon: Icons.contact_mail_outlined,
                  title: 'Contact Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileInfoRow(label: 'Department', value: profile.department),
                      ProfileInfoRow(label: 'Campus', value: profile.campus),
                      ProfileInfoRow(label: 'Email', value: profile.email),
                      ProfileInfoRow(label: 'Contact Number', value: profile.contactNumber),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
