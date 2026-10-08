import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// Güncel fiyat/kur kaynağı.
///
/// Şu an TCMB'nin resmî günlük kur bültenini (döviz) kullanır. Gram altın,
/// kripto ve hisse için API yoktur; o türlerde fiyat kullanıcı tarafından
/// manuel girilir.
class PriceService {
  PriceService._();

  static const String tcmbUrl = 'https://www.tcmb.gov.tr/kurlar/today.xml';

  /// TCMB'den döviz kurlarını çeker: `{ 'USD': 49.10, 'EUR': 54.99, ... }`.
  static Future<Map<String, double>> fetchTcmbRates() async {
    final resp = await http
        .get(Uri.parse(tcmbUrl))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('TCMB kuru alınamadı (HTTP ${resp.statusCode})');
    }

    final doc = XmlDocument.parse(resp.body);
    final rates = <String, double>{};

    for (final node in doc.findAllElements('Currency')) {
      final code = node.getAttribute('Kod');
      final buying = node.getElement('ForexBuying')?.innerText;
      if (code == null || buying == null || buying.trim().isEmpty) continue;

      final value = double.tryParse(buying.trim().replaceAll(',', '.'));
      if (value != null && value > 0) {
        rates[code] = value;
      }
    }

    return rates;
  }

  /// Varlık türünü TCMB kur koduna eşler. Desteklenmeyen türler için null.
  static String? currencyCodeForType(String type) {
    switch (type) {
      case 'USD':
        return 'USD';
      case 'EUR':
        return 'EUR';
      default:
        return null;
    }
  }
}
