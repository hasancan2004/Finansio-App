import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'notification_service.dart';
import 'recurring_schedule.dart';

/// Vade (borç/alacak) ve abonelik yenileme hatırlatmalarını veritabanındaki
/// güncel veriye göre kurar. Uygulama açılışında ve ilgili kayıtlarda değişiklik
/// olduğunda çağrılır.
class ReminderScheduler {
  ReminderScheduler._();

  static Future<void> scheduleAll(AppDatabase db) async {
    await scheduleDebts(db);
    await scheduleSubscriptions(db);
  }

  static Future<void> scheduleDebts(AppDatabase db) async {
    final now = DateTime.now();
    final debts = await (db.select(db.debts)
      ..where((d) => d.isSettled.equals(false) & d.dueDate.isNotNull()))
        .get();

    for (final d in debts) {
      final due = d.dueDate!;
      if (due.isBefore(now)) continue;

      await NotificationService.scheduleDebtReminder(
        debtId: d.id,
        personName: d.personName,
        amount: d.amount,
        isOwedToMe: d.isOwedToMe,
        dueDate: due,
      );
    }
  }

  static Future<void> scheduleSubscriptions(AppDatabase db) async {
    final now = DateTime.now();
    final rules = await (db.select(db.recurringRules)
      ..where((r) => r.isIncome.equals(false) & r.isActive.equals(true)))
        .get();

    for (final r in rules) {
      final next = RecurringSchedule.nextRunDateOnly(r);
      if (next == null || next.isBefore(now)) continue;

      await NotificationService.scheduleSubscriptionReminder(
        ruleId: r.id,
        name: (r.note?.isNotEmpty == true) ? r.note! : 'Abonelik',
        amount: r.amount.abs(),
        renewalDate: next,
      );
    }
  }
}
