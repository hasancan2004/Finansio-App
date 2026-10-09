import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/engine/transaction_parser.dart';
import '../../main.dart';
import '../database/app_database.dart';
import 'notification_listener_service.dart';

/// Yakalanan bildirimleri çözümleyip kullanıcı onayıyla işleme dönüştüren servis.
class TransactionCaptureService {
  TransactionCaptureService._();

  static const String _kEnabled = 'capture_enabled';

  static bool _started = false;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  static void start(AppDatabase db) {
    if (_started) return;
    _started = true;

    NotificationListenerService.init();

    NotificationListenerService.messages.listen((text) async {
      final enabled = await isEnabled();
      if (!enabled) return;

      final parsed = TransactionParser.parse(text);
      if (parsed == null) return;

      final navState = globalNavigatorKey.currentState;
      if (navState == null) return;
      final context = navState.context;

      _showCaptureDialog(context, db, parsed);
    });
  }

  static void _showCaptureDialog(
    BuildContext context,
    AppDatabase db,
    ParsedTransaction parsed,
  ) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İşlem Yakalandı 🔔'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parsed.note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              '${parsed.isIncome ? 'Gelir' : 'Gider'}: ${fmt.format(parsed.amount)} ₺',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: parsed.isIncome ? Colors.green : Colors.red,
              ),
            ),
            if (parsed.categoryName != null) ...[
              const SizedBox(height: 4),
              Text('Kategori: ${parsed.categoryName}',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              await _save(db, parsed);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  static Future<void> _save(AppDatabase db, ParsedTransaction parsed) async {
    final categoryId = await _findOrCreateCategory(db, parsed.categoryName);
    final amount = parsed.isIncome ? parsed.amount : -parsed.amount;

    await db.addTransaction(
      TransactionsCompanion.insert(
        amount: amount,
        categoryId: categoryId,
        note: Value(parsed.note),
        date: Value(DateTime.now()),
      ),
    );
  }

  static Future<int> _findOrCreateCategory(AppDatabase db, String? name) async {
    final cats = await db.allCategories();

    if (name != null && name.trim().isNotEmpty) {
      final norm = _norm(name);
      for (final c in cats) {
        if (_norm(c.name) == norm) return c.id;
      }
      for (final c in cats) {
        if (_norm(c.name).contains(norm) || norm.contains(_norm(c.name))) {
          return c.id;
        }
      }
      return db.addCategory(name: name.trim(), colorHex: '#607D8B');
    }

    if (cats.isNotEmpty) return cats.first.id;
    return db.addCategory(name: 'Diğer', colorHex: '#607D8B');
  }

  static String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u');
  }
}
