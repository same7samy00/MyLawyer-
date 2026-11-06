import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/payment_record.dart';

/// فاتورة الدفعة كملف PDF بالعربي، وبتفتح شاشة الموبايل للحفظ أو المشاركة
class InvoicePdfService {
  static const _primary = PdfColor.fromInt(0xFF1D4ED8);
  static const _dark = PdfColor.fromInt(0xFF0F172A);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _light = PdfColor.fromInt(0xFFEFF6FF);

  static Future<void> share(PaymentRecord payment) async {
    final bytes = await build(payment);
    await Printing.sharePdf(bytes: bytes, filename: 'My-Lawyer-${payment.reference ?? payment.id}.pdf');
  }

  static String _date(DateTime? date) {
    if (date == null) return '-';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} - ${two(date.hour)}:${two(date.minute)}';
  }

  static String _money(double value) => '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} ج.م';

  static Future<Uint8List> build(PaymentRecord payment) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf'));
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    pw.Widget row(String label, String value, {bool strong = false}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: _muted)),
              pw.Text(value, style: pw.TextStyle(fontSize: strong ? 13 : 11, fontWeight: pw.FontWeight.bold, color: strong ? _primary : _dark)),
            ],
          ),
        );

    final doc = pw.Document(title: 'فاتورة ${payment.reference ?? ''}', author: 'My Lawyer', theme: theme);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('فاتورة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: _dark)),
                    pw.SizedBox(height: 4),
                    pw.Text(payment.reference ?? '', style: const pw.TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('My Lawyer', textDirection: pw.TextDirection.ltr, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _primary)),
                    pw.SizedBox(height: 4),
                    pw.Text('my-lawyer.online', textDirection: pw.TextDirection.ltr, style: const pw.TextStyle(fontSize: 10, color: _muted)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 22),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(7)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const pw.BoxDecoration(
                      color: _light,
                      borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(7), topRight: pw.Radius.circular(7)),
                    ),
                    child: pw.Text('تفاصيل الدفعة', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _primary)),
                  ),
                  row('رقم الفاتورة', payment.reference ?? '-'),
                  row('التاريخ', _date(payment.at)),
                  row('رقم الطلب', payment.orderNumber ?? '-'),
                  row('الخدمة', payment.service),
                  if (payment.lawyerName != null) row('المحامي', payment.lawyerName!),
                  row('طريقة الدفع', payment.methodLabel),
                  row('الحالة', payment.statusLabel),
                  if (payment.refunded > 0) row('المبلغ المرتجع', _money(payment.refunded)),
                  row('الإجمالي', _money(payment.amount), strong: true),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Text(
              'الفاتورة دي اتعملت من تطبيق My Lawyer، ولأي استفسار كلمنا من «الدعم الفني» في التطبيق.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
