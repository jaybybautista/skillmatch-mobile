import 'package:flutter/material.dart';

/// Mirrors the web's `<x-status-badge>` component colors so a placement or
/// application shows the same status color on both platforms.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  static const _colors = <String, Color>{
    'pending': Color(0xFFB87700),
    'under_review': Color(0xFF3D6EF5),
    'interview': Color(0xFF7C3AED),
    'accepted': Color(0xFF16A34A),
    'approved': Color(0xFF16A34A),
    'rejected': Color(0xFFBE123C),
    'cancelled': Color(0xFFBE123C),
    'withdrawn': Color(0xFF64748B),
    'ongoing': Color(0xFF3D6EF5),
    'completed': Color(0xFF1D4ED8),
    'terminated': Color(0xFF7F1D1D),
    'active': Color(0xFF16A34A),
    'inactive': Color(0xFF64748B),
    'placed': Color(0xFF16A34A),
    'unplaced': Color(0xFF64748B),
  };

  Color get _color =>
      _colors[status.toLowerCase().trim()] ?? const Color(0xFF64748B);

  String get _label {
    final cleaned = status.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Unknown';
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
