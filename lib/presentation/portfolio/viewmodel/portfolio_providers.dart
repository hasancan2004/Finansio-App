// lib/presentation/portfolio/viewmodel/portfolio_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';

// Veritabanındaki varlıkları anlık dinleyen yayın
final assetsStreamProvider = StreamProvider.autoDispose<List<AssetItem>>((ref) {
  final db = ref.watch(dbProvider);
  return db.watchAssets();
});

// Toplam varlık değerini hesaplayan provider
final portfolioTotalProvider = Provider.autoDispose<double>((ref) {
  final assetsAsync = ref.watch(assetsStreamProvider);
  return assetsAsync.maybeWhen(
    data: (assets) {
      return assets.fold(0.0, (sum, asset) => sum + asset.totalCost);
    },
    orElse: () => 0.0,
  );
});