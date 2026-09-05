import 'package:flutter/material.dart';

/// Sinasabi kung bukas pa ba ang isang posting.
///
/// Dati, "12 slots available" lang ang nakikita nila - walang sinasabi pag
/// naubos na o pag sarado na, kaya may nagta-tap pa rin doon tapos saka lang
/// nila nalalaman sa dulo.
///
/// Sa server nanggagaling ang salita at ang kalagayan, hindi kinukuwenta dito,
/// kaya kaparehong-kapareho ito ng nasa web.
class AvailabilityTag extends StatelessWidget {
  const AvailabilityTag({
    super.key,
    required this.state,
    required this.label,
    this.compact = false,
  });

  /// open, full o closed.
  final String state;
  final String label;

  /// Mas maliit, para sa masikip na card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    // Kulay ayon sa dahilan. Berde pag pwede pa, dilaw pag napuno, abo pag
    // sarado na. Magkaiba yung huling dalawa - pwedeng magbukas ulit ang
    // napuno kapag may umatras, pero yung sinarado, sadyang isinara.
    final (background, foreground, icon) = switch (state) {
      'closed' => (
        const Color(0xFFEEF0F4),
        const Color(0xFF5B6478),
        Icons.close_rounded,
      ),
      'full' => (
        const Color(0xFFFFF4E5),
        const Color(0xFFB06F0A),
        Icons.warning_amber_rounded,
      ),
      _ => (
        const Color(0xFFEAFAF1),
        const Color(0xFF1A7F4B),
        null,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
