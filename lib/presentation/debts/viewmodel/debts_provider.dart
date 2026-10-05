import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';

// Projendeki dbProvider neredeyse onun yolunu import etmelisin.
// Örnek: import '../../../providers/db_provider.dart'; Veya main.dart içindeyse:
import '../../../main.dart';
import '../../transactions/viewmodel/tx_providers.dart';

// 1. Borçları ve alacakları anlık dinleyen Stream (Arayüz anında güncellenir)
final debtsStreamProvider = StreamProvider.autoDispose<List<DebtItem>>((ref) {
  final db = ref.watch(dbProvider);
  return db.watchDebts();
});

// 2. İşlemleri yönetecek Controller
final debtsControllerProvider = Provider.autoDispose<DebtsController>((ref) {
  final db = ref.watch(dbProvider);
  return DebtsController(db);
});

class DebtsController {
  final AppDatabase _db;
  DebtsController(this._db);

  // Kasa entegreli yeni borç/alacak ekleme
  Future<void> addDebt({
    required String personName,
    required double amount,
    required bool isOwedToMe,
    DateTime? dueDate,
  }) async {
    await _db.addDebtWithTransaction(
      personName: personName,
      amount: amount,
      isOwedToMe: isOwedToMe,
      dueDate: dueDate,
    );
  }

  // Kasa entegreli borcu kapatma (Ödendi İşareti + Bakiyeye Yansıtma)
  Future<void> settleDebt(int id) async {
    await _db.settleDebtWithTransaction(id);
  }

  // İşlemi tamamen silme
  Future<void> deleteDebt(int id) async {
    await _db.deleteDebt(id);
  }
}