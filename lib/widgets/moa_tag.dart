import 'package:flutter/material.dart';

/// "With MOA" means the company has a signed Memorandum of Agreement with the
/// school, so a placement there is officially covered by that agreement.
///
/// A coordinator or admin sets the flag on the company record, and the same
/// `companies.has_moa` column drives the identical tag on the website, so a
/// student sees the same thing on either platform.
class MoaTag extends StatelessWidget {
  const MoaTag({super.key, this.compact = true});

  /// The list cards are tight on space, so they use the smaller size. The
  /// posting detail has room for the roomier one.
  final bool compact;

  static const _green = Color(0xFF1A7F4B);
  static const _greenBackground = Color(0xFFEAFAF1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: _greenBackground,
        borderRadius: BorderRadius.circular(compact ? 5 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_outlined,
            size: compact ? 11 : 14,
            color: _green,
          ),
          SizedBox(width: compact ? 3 : 5),
          Text(
            'With MOA',
            style: TextStyle(
              color: _green,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
