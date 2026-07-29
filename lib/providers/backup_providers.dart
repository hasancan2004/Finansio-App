// lib/providers/backup_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finansio/providers/providers.dart';
import 'package:finansio/services/backup_service.dart';

final exportJsonProvider = FutureProvider.autoDispose<String>((ref) async {
  final db = ref.watch(dbProvider);
  return BackupService.exportJson(db);
});
