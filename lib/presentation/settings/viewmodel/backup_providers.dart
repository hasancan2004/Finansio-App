// lib/providers/backup_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import 'package:finansio/data/services/backup_service.dart';

final exportJsonProvider = FutureProvider.autoDispose<String>((ref) async {
  final db = ref.watch(dbProvider);
  return BackupService.exportJson(db);
});
