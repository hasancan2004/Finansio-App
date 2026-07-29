// lib/services/pdf_export_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // ✅ INTL PAKETİ EKLENDİ
import 'package:finansio/model/summary.dart';
import 'package:finansio/data/app_database.dart';

class PdfExportService {

  // ✅ YENİ: Parayı 100.000,00 TL formatına çeviren yardımcı fonksiyon
  static String _formatCurrency(double amount) {
    final formatter = NumberFormat("#,##0.00", "tr_TR");
    return '${formatter.format(amount)} TL';
  }

  // 1. MEVCUT PAYLAŞMA METODU (WhatsApp, Mail vb. için)
  static Future<void> generateAndShareMonthlyReport({
    required String monthName,
    required Summary summary,
    required List<Tx> transactions,
  }) async {
    final pdf = await _buildPdfDocument(monthName, summary, transactions);
    final Uint8List bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Finansio_Rapor_$monthName.pdf',
    );
  }

  // 2. YENİ İNDİRME METODU (Dosyayı cihaza kaydeder ve yolunu döner)
  static Future<String?> downloadMonthlyReport({
    required String monthName,
    required Summary summary,
    required List<Tx> transactions,
  }) async {
    final pdf = await _buildPdfDocument(monthName, summary, transactions);
    final Uint8List bytes = await pdf.save();

    try {
      Directory? directory;
      if (Platform.isAndroid) {
        // Android cihazlarda doğrudan İndirilenler klasörüne erişim
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        // iOS için Dokümanlar klasörü
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final String filePath = '${directory.path}/Finansio_Rapor_$monthName.pdf';
        final File file = File(filePath);
        await file.writeAsBytes(bytes);
        return filePath; // Başarılı olursa dosya yolunu dön
      }
    } catch (e) {
      print("İndirme hatası: $e");
    }
    return null;
  }

  // Ortak PDF Tasarım Oluşturucu
  static Future<pw.Document> _buildPdfDocument(String monthName, Summary summary, List<Tx> transactions) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(monthName, fontBold),
            pw.SizedBox(height: 20),
            _buildSummaryCards(summary, font, fontBold),
            pw.SizedBox(height: 30),
            _buildTransactionTable(transactions, font, fontBold),
          ];
        },
      ),
    );
    return pdf;
  }

  // --- ALT BİLEŞENLER (WIDGET'LAR) ---

  static pw.Widget _buildHeader(String monthName, pw.Font fontBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Finansio Aylik Rapor',
          style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue800),
        ),
        pw.Text(
          monthName,
          style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCards(Summary summary, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _summaryBox('Gelir', summary.income, PdfColors.green700, font, fontBold),
        _summaryBox('Gider', summary.expense, PdfColors.red700, font, fontBold),
        _summaryBox('Net', summary.net, summary.net >= 0 ? PdfColors.green700 : PdfColors.red700, font, fontBold),
      ],
    );
  }

  static pw.Widget _summaryBox(String title, double amount, PdfColor color, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          // ✅ FORMAT FONKSİYONU KULLANILDI
          pw.Text(
            _formatCurrency(amount),
            style: pw.TextStyle(font: fontBold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTransactionTable(List<Tx> txs, pw.Font font, pw.Font fontBold) {
    final tableData = txs.map((t) {
      return [
        t.date.toIso8601String().split('T')[0],
        t.category.name,
        t.note ?? '-',
        // ✅ FORMAT FONKSİYONU KULLANILDI
        _formatCurrency(t.amount),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Tarih', 'Kategori', 'Aciklama', 'Tutar'],
      data: tableData,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
    );
  }
}