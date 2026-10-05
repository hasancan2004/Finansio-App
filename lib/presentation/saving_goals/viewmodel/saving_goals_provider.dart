import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../data/database/app_database.dart';
import '../../../main.dart'; // Senin projendeki yola göre
import '../../transactions/viewmodel/tx_providers.dart';

// 1. Hedefleri anlık dinleyen StreamProvider (Değişiklik anında UI güncellenir)
final savingGoalsStreamProvider = StreamProvider.autoDispose<List<SavingGoalItem>>((ref) {
  final db = ref.watch(dbProvider);
  return db.watchSavingGoals();
});

// 2. Hedef ekleme, silme, düzenleme ve para ekleme işlemlerini yönetecek Controller
final savingGoalsControllerProvider = Provider.autoDispose<SavingGoalsController>((ref) {
  final db = ref.watch(dbProvider);
  return SavingGoalsController(db);
});

class SavingGoalsController {
  final AppDatabase _db;
  SavingGoalsController(this._db);

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    DateTime? targetDate,
    required String colorHex,
    required String iconName,
  }) async {
    await _db.addSavingGoal(SavingGoalsCompanion.insert(
      title: title,
      targetAmount: targetAmount,
      targetDate: targetDate != null ? Value(targetDate) : const Value.absent(),
      colorHex: Value(colorHex),
      iconName: Value(iconName),
    ));
  }

  Future<void> updateGoal({
    required int id,
    String? title,
    double? targetAmount,
  }) async {
    await _db.updateSavingGoal(
      id: id,
      title: title,
      targetAmount: targetAmount,
    );
  }

  // ✅ YENİ: Kumbaraya para atarken ana bakiyeden GİDER olarak düşme
  Future<void> addMoneyToGoal(int goalId, double amount, String goalTitle) async {
    // 1. Kumbaranın içindeki hedef miktarını artır
    await _db.addMoneyToGoal(goalId, amount);

    // 2. "Birikim" veya "Kumbara" adında bir kategori var mı bul
    final categories = await _db.allCategories();
    int? categoryId;
    try {
      final birikimCat = categories.firstWhere(
              (c) => c.name.toLowerCase() == 'birikim' || c.name.toLowerCase() == 'kumbara'
      );
      categoryId = birikimCat.id;
    } catch (e) {
      // Yoksa arka planda sessizce "Birikim" kategorisini oluştur
      categoryId = await _db.addCategory(name: 'Birikim', colorHex: '#3B82F6');
    }

    // 3. İşlemler tablosuna (ana ekrana) GİDER (-) olarak yansıt
    await _db.addTransaction(TransactionsCompanion.insert(
      amount: -amount, // Gider olduğu için eksi yapıyoruz
      categoryId: categoryId,
      note: Value('$goalTitle kumbarasına aktarıldı'),
      date: Value(DateTime.now()),
    ));
  }

  Future<void> deleteGoal(int id) async {
    await _db.deleteSavingGoal(id);
  }
}