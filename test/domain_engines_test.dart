import 'package:flutter_test/flutter_test.dart';

import 'package:finansio/domain/engine/account_engine.dart';
import 'package:finansio/domain/engine/saving_goal_engine.dart';
import 'package:finansio/domain/engine/transaction_parser.dart';
import 'package:finansio/domain/models/account.dart';

void main() {
  group('TransactionParser', () {
    test('harcama bildirimini çözer', () {
      final p = TransactionParser.parse('Kartınızdan 150,00 TL harcama yapılmıştır');
      expect(p, isNotNull);
      expect(p!.amount, 150.0);
      expect(p.isIncome, false);
    });

    test('para girişi bildirimini çözer', () {
      final p = TransactionParser.parse('Hesabınıza 5.000,00 TL geldi');
      expect(p, isNotNull);
      expect(p!.amount, 5000.0);
      expect(p.isIncome, true);
    });

    test('binlik ayraçlı tutarı ve kategoriyi çözer', () {
      final p = TransactionParser.parse('1.234,56 TL market alışverişi yapıldı');
      expect(p, isNotNull);
      expect(p!.amount, 1234.56);
      expect(p.categoryName, 'Yemek');
    });

    test('tutar yoksa null döner', () {
      expect(TransactionParser.parse('bu bir test mesajı'), isNull);
    });
  });

  group('SavingGoalEngine', () {
    final now = DateTime(2026, 10, 12);
    final createdAt = DateTime(2026, 6, 12); // ~4 ay önce

    test('kalan süreyi kestirir', () {
      final e = SavingGoalEngine.estimate(
        currentAmount: 3000,
        targetAmount: 6000,
        createdAt: createdAt,
        now: now,
      );
      expect(e.isCompleted, false);
      expect(e.monthsToReach, isNotNull);
      expect(e.monthsToReach!, greaterThan(3.0));
      expect(e.monthsToReach!, lessThan(5.0));
      expect(e.estimatedFinish!.isAfter(now), true);
    });

    test('hedef tamamlandıysa işaretler', () {
      final e = SavingGoalEngine.estimate(
        currentAmount: 6000,
        targetAmount: 6000,
        createdAt: createdAt,
        now: now,
      );
      expect(e.isCompleted, true);
    });

    test('ilerleme yoksa tahmin üretmez', () {
      final e = SavingGoalEngine.estimate(
        currentAmount: 0,
        targetAmount: 100,
        createdAt: now,
        now: now,
      );
      expect(e.monthsToReach, isNull);
      expect(e.estimatedFinish, isNull);
    });
  });

  group('AccountEngine', () {
    test('ekstre dönemini hesaplar', () {
      final period = AccountEngine.statementPeriod(DateTime(2026, 10, 12), 15);
      expect(period.start, DateTime(2026, 9, 15));
      expect(period.end, DateTime(2026, 10, 15));
    });

    test('son ödeme tarihini hesaplar', () {
      final due = AccountEngine.dueDateFor(DateTime(2026, 10, 15), 25);
      expect(due, DateTime(2026, 10, 25));
    });

    test('bakiyeyi işlem ve transferlerle toplar', () {
      final s = AccountEngine.summarize(
        id: 1,
        name: 'Nakit',
        type: AccountType.cash,
        initialBalance: 1000,
        transactionSum: -250,
        transferSum: 100,
        colorHex: '#000000',
        iconName: 'cash',
        isArchived: false,
      );
      expect(s.currentBalance, 850.0);
    });

    test('tür eşlemesi doğru', () {
      expect(AccountType.fromDb('credit_card'), AccountType.creditCard);
      expect(AccountType.fromDb('bank').isCreditCard, false);
    });
  });
}
