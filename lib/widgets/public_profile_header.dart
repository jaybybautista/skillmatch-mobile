import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The cover + circular avatar header shared by every read-only profile
/// screen (student, company, coordinator) — the mobile equivalent of the
/// web's `profile-viewer-shell` partial.
class PublicProfileHeader extends StatelessWidget {
  const PublicProfileHeader({
    super.key,
    required this.name,
    required this.initials,
    this.avatarUrl,
    this.coverUrl,
    this.isSquareAvatar = false,
    this.subtitle,
    this.chips = const [],
  });

  final String name;
  final String initials;
  final String? avatarUrl;
  final String? coverUrl;

  /// True for a company logo (rounded square); false for a person's face
  /// (circle).
  final bool isSquareAvatar;
  final String? subtitle;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.chipBackground,
            image: coverUrl != null
                ? DecorationImage(image: NetworkImage(coverUrl!), fit: BoxFit.cover)
                : null,
          ),
        ),
        Transform.translate(
          // Less overlap than the avatar alone would suggest, so the name
          // clears the bottom edge of the cover photo instead of crowding
          // into it — the avatar can peek over the cover, but the text
          // needs its own breathing room below it.
          offset: const Offset(0, -22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: isSquareAvatar ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isSquareAvatar ? BorderRadius.circular(16) : null,
                  ),
                  child: avatarUrl != null
                      ? ClipRRect(
                          borderRadius: isSquareAvatar ? BorderRadius.circular(13) : BorderRadius.circular(999),
                          child: Image.network(avatarUrl!, fit: BoxFit.cover),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            shape: isSquareAvatar ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: isSquareAvatar ? BorderRadius.circular(13) : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (chips.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, -16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 8, runSpacing: 6, children: chips),
            ),
          ),
      ],
    );
  }
}

class ProfileMetaChip extends StatelessWidget {
  const ProfileMetaChip({super.key, required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, color: tint, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasValue ? value! : 'Not specified',
              style: TextStyle(
                fontSize: 13.5,
                color: hasValue ? AppColors.textDark : AppColors.textMuted,
                fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoDataText extends StatelessWidget {
  const NoDataText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic),
    );
  }
}
