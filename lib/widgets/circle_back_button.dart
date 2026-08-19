import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A circular outlined back button — a light border ring around a centered
/// chevron — used in place of the default [BackButton]/AppBar back arrow
/// wherever a screen needs a back affordance.
///
/// Wrapped in [UnconstrainedBox] so it renders at its natural 40x40 size
/// whether it's placed freely (e.g. [Align]) or inside an AppBar's `leading`
/// slot, which otherwise forces its child to fill a 56-wide tight box.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({
    super.key,
    this.onPressed,
    this.borderColor = AppColors.border,
    this.iconColor = AppColors.textDark,
    this.filled = false,
  });

  final VoidCallback? onPressed;

  /// Override for use on a dark background (e.g. the setup wizard's blue
  /// header), where the ring and chevron need to be white instead.
  final Color borderColor;
  final Color iconColor;

  /// A solid white circle with a straight blue arrow instead of the default
  /// outlined ring with a chevron — used on the profile-setup wizard's blue
  /// header, where [borderColor]/[iconColor] are ignored.
  final bool filled;

  static const double _size = 40;
  static const double _filledSize = 30;

  @override
  Widget build(BuildContext context) {
    final size = filled ? _filledSize : _size;

    return UnconstrainedBox(
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: filled ? Colors.white : Colors.transparent,
          shape: filled
              ? const CircleBorder()
              : CircleBorder(side: BorderSide(color: borderColor, width: 1.4)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed ?? () => Navigator.of(context).maybePop(),
            child: Icon(
              filled ? Icons.arrow_back_rounded : Icons.chevron_left,
              color: filled ? AppColors.primary : iconColor,
              size: filled ? 16 : 24,
            ),
          ),
        ),
      ),
    );
  }
}