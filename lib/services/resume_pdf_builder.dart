import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/resume.dart';
import '../models/student_profile.dart';
import 'resume_display.dart';

const _navy = PdfColor.fromInt(0xFF003486);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _dark = PdfColor.fromInt(0xFF1A1E2B);
const _chipBg = PdfColor.fromInt(0xFFEAF0FB);

const _asciiReplacements = {
  '–': '-', // en dash
  '—': '-', // em dash
  '‘': "'", // left single quote
  '’': "'", // right single quote
  '“': '"', // left double quote
  '”': '"', // right double quote
  '…': '...', // ellipsis
  '•': '-', // bullet
  ' ': ' ', // non-breaking space
};

/// Swaps "smart" punctuation (en/em dashes, curly quotes, bullets — the kind
/// the Groq AI Help feature and OCR import both routinely produce) for plain
/// ASCII equivalents. Roboto (below) covers these fine when the font
/// downloads successfully, but this keeps the PDF free of missing-glyph
/// boxes even when it can't (offline, or a network that blocks the Google
/// Fonts CDN) — the base14 fallback font only supports WinAnsi.
String _pdfSafe(String text) {
  var result = text;
  for (final entry in _asciiReplacements.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

/// Renders the exact same content ResumePreviewScreen shows on-screen (which
/// itself mirrors the web's resume-builder preview page) into a downloadable
/// PDF, for the Download action.
///
/// The base14 Helvetica font the `pdf` package falls back to otherwise can't
/// draw plenty of characters that show up in real resume content — en/em
/// dashes, curly quotes, bullets — including ones the Groq AI Help feature
/// and OCR import both routinely produce. Roboto (fetched once and cached
/// by the `printing` package) covers all of that.
Future<Uint8List> buildResumePdf(Resume resume, StudentProfile? profile) async {
  final header = computeResumeHeader(resume, profile);
  final sections = nonBasicInfoSections(resume);

  final baseFont = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();
  final italicFont = await PdfGoogleFonts.robotoItalic();
  final boldItalicFont = await PdfGoogleFonts.robotoBoldItalic();

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont, italic: italicFont, boldItalic: boldItalicFont),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      build: (context) => [
        pw.Center(
          child: pw.Text(
            _pdfSafe(header.fullName.toUpperCase()),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6),
          ),
        ),
        if (header.course != null) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(_pdfSafe(header.course!), style: const pw.TextStyle(fontSize: 9, color: _muted, letterSpacing: 1)),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            _pdfSafe([
              if (header.addressLine.isNotEmpty) header.addressLine,
              if (header.phone != null && header.phone!.isNotEmpty) header.phone!,
              if (header.email != null && header.email!.isNotEmpty) header.email!,
            ].join('  |  ')),
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ),
        for (final section in sections) _buildSection(section),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _buildSection(ResumeSection section) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1))),
          child: pw.Text(
            _pdfSafe(section.title.toUpperCase()),
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 0.8),
          ),
        ),
        pw.SizedBox(height: 8),
        _buildSectionBody(section),
      ],
    ),
  );
}

pw.Widget _empty(String label) =>
    pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _muted, fontStyle: pw.FontStyle.italic));

pw.Widget _buildSectionBody(ResumeSection section) {
  const bodyStyle = pw.TextStyle(fontSize: 10, color: _dark, lineSpacing: 2);

  switch (section.type) {
    case 'professional_summary':
      return section.content == null || section.content!.isEmpty
          ? _empty('No summary added yet.')
          : pw.Text(_pdfSafe(section.content!), style: bodyStyle);

    case 'experience':
      if (section.experiences.isEmpty) return _empty('No experience added yet.');
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final e in section.experiences)
            _entry(
              title: e.jobTitle ?? '',
              subtitle: [e.company, e.address].where((s) => s != null && s.isNotEmpty).join(' - '),
              period: '${e.periodStart ?? ''} - ${e.periodEnd ?? ''}',
              description: e.responsibilities,
            ),
        ],
      );

    case 'achievements':
      if (section.achievements.isEmpty) return _empty('No achievements added yet.');
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final a in section.achievements)
            _entry(
              title: a.title ?? '',
              subtitle: [a.category, a.location].where((s) => s != null && s.isNotEmpty).join(' - '),
              period: a.dateText ?? '',
            ),
        ],
      );

    case 'projects':
      if (section.projects.isEmpty) return _empty('No projects added yet.');
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final p in section.projects) _entry(title: p.title ?? '', description: p.description),
        ],
      );

    case 'education':
      if (section.education.isEmpty) return _empty('No education added yet.');
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final e in section.education)
            _entry(
              title: e.schoolName ?? '',
              subtitle: e.degree ?? '',
              period: '${e.startDate ?? ''} - ${e.endDate ?? ''}',
            ),
        ],
      );

    case 'skills':
      if (section.technicalSkills.isEmpty && section.softSkills.isEmpty) return _empty('No skills added yet.');
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _skillColumn('Technical Skills', section.technicalSkills)),
          pw.SizedBox(width: 16),
          pw.Expanded(child: _skillColumn('Soft Skills', section.softSkills)),
        ],
      );

    case 'custom':
      if (section.content == null || section.content!.isEmpty) return _empty('Nothing added yet.');
      if (section.inputType == 'bullet_points') {
        final lines = section.content!.split('\n').where((l) => l.trim().isNotEmpty);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(_pdfSafe('-  ${line.trim()}'), style: bodyStyle),
              ),
          ],
        );
      }
      return pw.Text(_pdfSafe(section.content!), style: bodyStyle);

    default:
      return pw.SizedBox();
  }
}

pw.Widget _entry({required String title, String? subtitle, String? period, String? description}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 9),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_pdfSafe(title), style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
        if (subtitle != null && subtitle.isNotEmpty)
          pw.Text(_pdfSafe(subtitle), style: const pw.TextStyle(fontSize: 9, color: _muted)),
        if (period != null && period.trim().isNotEmpty && period != ' - ')
          pw.Text(_pdfSafe(period), style: pw.TextStyle(fontSize: 8.5, color: _muted, fontStyle: pw.FontStyle.italic)),
        if (description != null && description.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(_pdfSafe(description), style: const pw.TextStyle(fontSize: 9.5, color: _dark, lineSpacing: 2)),
        ],
      ],
    ),
  );
}

pw.Widget _skillColumn(String label, List<ResumeSkillEntry> skills) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label.toUpperCase(),
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _muted, letterSpacing: 0.4),
      ),
      pw.SizedBox(height: 5),
      pw.Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final skill in skills)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: pw.BoxDecoration(color: _chipBg, borderRadius: pw.BorderRadius.circular(3)),
              child: pw.Text(_pdfSafe(skill.skillName), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            ),
        ],
      ),
    ],
  );
}
