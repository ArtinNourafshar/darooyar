import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/reports/report_models.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

/// ساخت و ذخیرهٔ PDF گزارش مصرف دارو.
///
/// ویژگی‌ها: راست‌چین، فونت IRANYekan (عادی + بولد)، جدول چندصفحه‌ای
/// با سرصفحهٔ تکراری، آمار و درصد پایبندی.
class PdfReportService {
  PdfReportService._();

  static const String _regularFontPath =
      'assets/fonts/IRANYekan-Regular.ttf';
  static const String _boldFontPath = 'assets/fonts/IRANYekan-Bold.ttf';

  /// ردیف‌های جدول در هر صفحه (فضای امن برای A4 با فونت ۱۰).
  static const int _rowsPerPage = 22;

  /// ساخت PDF و ذخیره در پوشهٔ اسناد؛ مسیر فایل ذخیره‌شده برمی‌گردد.
  static Future<String> export({
    required List<DoseSlot> rows,
    required ReportStats stats,
    required String rangeLabel,
    required String profileLabel,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load(_regularFontPath));
    final bold = pw.Font.ttf(await rootBundle.load(_boldFontPath));
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final doc = pw.Document();

    // جدول‌ها به صورت فیزیکی چپ‌به‌راست چیده می‌شوند؛ برای خوانایی
    // راست‌به‌چپِ فارسی، ستون‌ها برعکس (تاریخ در سمت راست) قرار می‌گیرند.
    final chunks = <List<DoseSlot>>[];
    for (var i = 0; i < rows.length; i += _rowsPerPage) {
      chunks.add(rows.sublist(
        i,
        i + _rowsPerPage > rows.length ? rows.length : i + _rowsPerPage,
      ));
    }
    if (chunks.isEmpty) chunks.add(const []);

    final pageCount = chunks.length;
    final generatedAt = DateTime.now();

    for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
          theme: theme,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _titleBlock(
                  rangeLabel: rangeLabel,
                  profileLabel: profileLabel,
                  generatedAt: generatedAt,
                ),
                if (pageIndex == 0) ...[
                  pw.SizedBox(height: 14),
                  _statsBlock(stats),
                ],
                pw.SizedBox(height: 14),
                _table(chunks[pageIndex]),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'دارویار — یادآور داروی خانوادگی',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      PersianUtils.toPersianDigits(
                        'صفحه ${pageIndex + 1} از $pageCount',
                      ),
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(dir.path, 'darooyar_reports'));
    await reportsDir.create(recursive: true);

    final stamp = generatedAt
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(reportsDir.path, 'گزارش_دارویار_$stamp.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static pw.Widget _titleBlock({
    required String rangeLabel,
    required String profileLabel,
    required DateTime generatedAt,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'گزارش مصرف دارو',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'بازه: $rangeLabel  •  فرد: $profileLabel',
          style: pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800),
        ),
        pw.Text(
          'تاریخ صدور: ${PersianUtils.formatJalaliLong(generatedAt)} — '
          '${PersianUtils.formatTime(generatedAt)}',
          style: pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.grey400, thickness: 0.8),
      ],
    );
  }

  static pw.Widget _statsBlock(ReportStats stats) {
    String cell(String label, String value) => '$label: $value';

    final items = <String>[
      cell('کل نوبت‌ها', PersianUtils.toPersianDigits('${stats.total}')),
      cell('خورده شده', PersianUtils.toPersianDigits('${stats.taken}')),
      cell('نخورده', PersianUtils.toPersianDigits('${stats.skipped}')),
      cell('مصرف نشده', PersianUtils.toPersianDigits('${stats.missed}')),
      cell(
        'درصد پایبندی',
        '${PersianUtils.toPersianDigits(stats.adherencePercent.toStringAsFixed(0))}٪',
      ),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Wrap(
        spacing: 18,
        runSpacing: 6,
        children: [
          for (final item in items)
            pw.Text(
              item,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _table(List<DoseSlot> pageRows) {
    const headers = ['وضعیت', 'دوز', 'دارو', 'فرد', 'ساعت', 'تاریخ'];

    final data = <List<String>>[
      for (final row in pageRows)
        [
          row.status.label,
          row.dose,
          row.medicationName,
          row.profileName,
          row.timeLabel,
          PersianUtils.formatJalaliFromDateKey(row.dateKey),
        ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerDirection: pw.TextDirection.rtl,
      tableDirection: pw.TextDirection.rtl,
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.centerRight,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey800,
      ),
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      tableWidth: pw.TableWidth.max,
      columnWidths: {
        // ترتیب فیزیکی برعکسِ خوانش راست‌به‌چپ است.
        0: const pw.FlexColumnWidth(1.15), // وضعیت
        1: const pw.FlexColumnWidth(1.0), // دوز
        2: const pw.FlexColumnWidth(1.5), // دارو
        3: const pw.FlexColumnWidth(1.1), // فرد
        4: const pw.FlexColumnWidth(0.9), // ساعت
        5: const pw.FlexColumnWidth(1.3), // تاریخ
      },
    );
  }
}
