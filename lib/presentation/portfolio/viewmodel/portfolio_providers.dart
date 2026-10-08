// lib/presentation/portfolio/viewmodel/portfolio_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/data/services/price_service.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';

// Veritabanındaki varlıkları anlık dinleyen yayın
final assetsStreamProvider = StreamProvider.autoDispose<List<AssetItem>>((ref) {
  final db = ref.watch(dbProvider);
  return db.watchAssets();
});

// Toplam varlık değerini hesaplayan provider (maliyet)
final portfolioTotalProvider = Provider.autoDispose<double>((ref) {
  final assetsAsync = ref.watch(assetsStreamProvider);
  return assetsAsync.maybeWhen(
    data: (assets) {
      return assets.fold(0.0, (sum, asset) => sum + asset.totalCost);
    },
    orElse: () => 0.0,
  );
});

/// Portföy özeti: toplam maliyet, güncel değer ve kâr/zarar.
class PortfolioSummary {
  final double totalCost;
  final double currentValue;
  final double profitLoss;
  final int assetCount;

  double get profitLossPercent => totalCost > 0 ? profitLoss / totalCost : 0;

  const PortfolioSummary({
    required this.totalCost,
    required this.currentValue,
    required this.profitLoss,
    required this.assetCount,
  });

  const PortfolioSummary.empty()
      : totalCost = 0,
        currentValue = 0,
        profitLoss = 0,
        assetCount = 0;
}

final portfolioSummaryProvider = Provider.autoDispose<PortfolioSummary>((ref) {
  final assetsAsync = ref.watch(assetsStreamProvider);
  return assetsAsync.maybeWhen(
    data: (assets) {
      double cost = 0, value = 0;
      for (final a in assets) {
        cost += a.totalCost;
        value += a.currentValue;
      }
      return PortfolioSummary(
        totalCost: cost,
        currentValue: value,
        profitLoss: value - cost,
        assetCount: assets.length,
      );
    },
    orElse: () => const PortfolioSummary.empty(),
  );
});

/// TCMB kurlarını çekip USD/EUR varlıklarının güncel fiyatını güncelleyen
/// controller. Geri dönüş: güncellenen varlık sayısı.
final portfolioControllerProvider =
    Provider.autoDispose<PortfolioController>((ref) {
  final db = ref.watch(dbProvider);
  return PortfolioController(db);
});

class PortfolioController {
  final AppDatabase _db;
  PortfolioController(this._db);

  Future<int> refreshPrices() async {
    final rates = await PriceService.fetchTcmbRates();
    final assets = await _db.select(_db.assets).get();

    int updated = 0;
    for (final a in assets) {
      final code = PriceService.currencyCodeForType(a.type);
      if (code == null) continue;
      final price = rates[code];
      if (price == null) continue;

      await _db.updateAsset(id: a.id, currentPrice: price);
      updated++;
    }

    return updated;
  }
}
