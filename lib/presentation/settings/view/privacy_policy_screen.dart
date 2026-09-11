import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gizlilik Politikası"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SelectionArea(
            child: Text(
              _policyTr,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: cs.onSurface.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const String _policyTr = '''
Finansio Gizlilik Politikası

Son güncelleme: 2026-02-13

Finansio (“Uygulama”), kişisel gelir/gider takibi yapmanızı sağlayan bir mobil uygulamadır. Gizliliğinizi önemsiyoruz. Bu politika, hangi verilerin işlendiğini ve nasıl korunduğunu açıklar.

1) Toplanan Veriler
Finansio, aşağıdaki verileri yalnızca cihazınızda saklar:
• İşlemler: tutar, tarih, not ve kategori bilgileri
• Bütçeler: kategori bazlı aylık bütçe değerleri
• Tekrarlayan kurallar: belirlediğiniz periyodik işlem kuralları
• Kategori düzeltmeleri: kategori önerilerini geliştirmek için seçtiğiniz eşleştirmeler
• Uygulama ayarları: tema, vurgu rengi ve bildirim tercihleri

Uygulama, bu verileri geliştiriciye otomatik olarak göndermez.

2) Verilerin Saklanması
Veriler cihazınızda, yerel veritabanında (SQLite/Drift) saklanır.

3) Yedekleme ve Paylaşım
Uygulama, isteğinizle JSON/CSV yedeği oluşturabilir ve paylaşım (Share) ekranı üzerinden dışa aktarabilir. Yedek dosyalarını kimlerle paylaştığınız tamamen sizin kontrolünüzdedir.

4) Bildirimler
Günlük hatırlatma ve uyarılar için bildirim izni istenebilir. Bildirimler cihaz üzerinde planlanır ve kişisel verileriniz geliştiriciye gönderilmez.

5) Üçüncü Taraf Hizmetler
Finansio; analiz, reklam veya takip (tracking) amacıyla üçüncü taraf SDK kullanmaz. (Kullandığınız paketler; dosya seçme veya paylaşım gibi işlevler için kullanılabilir.)

6) Veri Güvenliği
Verileri korumak için makul teknik önlemler alınır. Ancak hiçbir sistem %100 güvenli değildir. Cihaz güvenliğiniz (ekran kilidi vb.) verilerin korunmasında önemlidir.

7) Çocukların Gizliliği
Uygulama 13 yaş altına yönelik değildir ve bilerek çocuklardan veri toplamaz.

8) Silme / Sıfırlama
Ayarlar > Danger Zone bölümünden tüm verileri silebilirsiniz. Bu işlem geri alınamaz.

9) İletişim
Gizlilikle ilgili sorularınız için:
E-posta: hasancan.kula0707@gmail.com

Bu politika gerektiğinde güncellenebilir.


Finansio Privacy Policy

Last updated: 2026-02-13

Finansio (“the App”) helps you track personal income and expenses. We respect your privacy. This policy explains what data is processed and how it is handled.

1) Data We Collect
The App stores the following data locally on your device:
• Transactions (amount, date, note, category)
• Budgets (monthly category budgets)
• Recurring rules (your periodic transaction rules)
• Category overrides (your corrections to improve suggestions)
• App settings (theme, accent color, notification preferences)

The App does not automatically send your data to the developer.

2) Data Storage
Your data is stored locally in a SQLite database (Drift).

3) Backup and Sharing
You may export backups (JSON/CSV) and share them using the system share sheet. You control where and with whom the backup files are shared.

4) Notifications
The App may request notification permission to schedule reminders and alerts locally on your device. No personal data is sent to the developer for notifications.

5) Third-Party Services
Finansio does not use third-party SDKs for analytics, ads, or tracking.

6) Security
We take reasonable measures to protect your data. However, no method of storage is 100% secure. Your device security (screen lock, etc.) matters.

7) Children
The App is not intended for children under 13 and does not knowingly collect personal data from them.

8) Deletion
You can delete all data via Settings > Danger Zone. This action is irreversible.

9) Contact
Email: hasancan.kula0707@gmail.com

This policy may be updated from time to time.

''';