import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../data/database/app_database.dart';
import '../../transactions/viewmodel/tx_providers.dart'; // dbProvider nerede tanımlıysa orayı import et
import '../../../data/services/notification_service.dart';
import '../../../data/services/reminder_scheduler.dart';

// Sadece gider (isIncome = false) olan tekrarlayan işlemleri (Abonelikleri) çeker
final subscriptionsStreamProvider = StreamProvider.autoDispose<List<RecurringRule>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.recurringRules)
    ..where((r) => r.isIncome.equals(false))
    ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
      .watch();
});

// Abonelikleri yönetmek (Silmek, Aktif/Pasif yapmak) için Controller
final subscriptionsControllerProvider = Provider.autoDispose<SubscriptionsController>((ref) {
  final db = ref.watch(dbProvider);
  return SubscriptionsController(db);
});

class SubscriptionsController {
  final AppDatabase _db;
  SubscriptionsController(this._db);

  Future<void> toggleActive(int id, bool currentStatus) async {
    await (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(isActive: Value(!currentStatus)),
    );

    final nowActive = !currentStatus;
    if (nowActive) {
      await ReminderScheduler.scheduleSubscriptions(_db);
    } else {
      await NotificationService.cancelSubscriptionReminder(id);
    }
  }

  Future<void> deleteSubscription(int id) async {
    await (_db.delete(_db.recurringRules)..where((r) => r.id.equals(id))).go();
    await NotificationService.cancelSubscriptionReminder(id);
  }

  // ✅ YENİ: Abonelik Ekleme Fonksiyonu
  Future<void> addSubscription({
    required String name,
    required double amount,
    required String frequency, // 'monthly', 'yearly', 'weekly'
    required DateTime startDate,
  }) async {
    // 1. "Abonelik" kategorisini bul veya oluştur
    final cats = await _db.allCategories();
    int categoryId;
    try {
      categoryId = cats.firstWhere((c) => c.name.toLowerCase() == 'abonelik').id;
    } catch (_) {
      categoryId = await _db.addCategory(name: 'Abonelik', colorHex: '#9C27B0'); // Mor renk
    }

    // 2. Kuralı (RecurringRule) veritabanına kaydet
    // Not: Gider olduğu için amount negatif (-) olarak kaydedilir
    await _db.into(_db.recurringRules).insert(
      RecurringRulesCompanion.insert(
        isIncome: const Value(false),
        amount: -amount,
        categoryId: categoryId,
        note: Value(name),
        frequency: frequency,
        interval: const Value(1), // Varsayılan 1 (1 ayda bir, 1 haftada bir vs.)
        startDate: Value(startDate),
        isActive: const Value(true),
      ),
    );

    // 3. Yenileme hatırlatmalarını güncelle
    await ReminderScheduler.scheduleSubscriptions(_db);
  }
}