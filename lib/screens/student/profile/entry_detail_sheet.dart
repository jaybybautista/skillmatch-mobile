import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Isang hanay ng detalye sa loob ng kahon.
class EntryDetail {
  const EntryDetail(this.label, this.value);

  final String label;
  final String? value;
}

/// Ipinapakita ang buong laman ng isang hanay sa profile.
///
/// Yung card, maikli lang - pangalan, isang linya, at petsa. Yung iba pang
/// isinulat nila, hindi nakikita doon: yung paglalarawan ng proyekto, yung
/// link, yung buong petsa. Dito nila makikita yun, sa isang pindot.
///
/// Kapareho ito ng kahong bumubukas sa web, kaya pareho ang nakikita nila
/// kahit saan nila buksan ang profile nila.
Future<void> showEntryDetails(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<EntryDetail> details,
}) {
  // Yung blangko, tinatanggal. Walang silbi ang hilerang walang laman, at
  // mas mahaba pa ang kahon kaysa sa laman nito kung isasama.
  final rows = details
      .where((d) => (d.value ?? '').trim().isNotEmpty)
      .toList();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Mas maikli kaysa sa nakagawian. Isang pindot lang ito para tumingin,
    // kaya dapat mabilis - yung dalawang daan at limampung millisecond na
    // nakatakda, ramdam bilang paghihintay.
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 160),
      reverseDuration: Duration(milliseconds: 120),
    ),
    builder: (_) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppFonts.title(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textMuted,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 32),
                    child: Text(
                      'Nothing else was filled in for this one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[i].label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // SelectableText para makopya nila yung link o yung
                          // mahabang paglalarawan.
                          SelectableText(
                            rows[i].value!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
