// lib/services/backup_service.dart
import 'dart:convert';

import 'package:finansio/data/app_database.dart';

class BackupService {
  static Future<String> exportJson(AppDatabase db) async {
    final cats = await db.select(db.categories).get();
    final txs = await db.select(db.transactions).get();
    final budgets = await db.select(db.budgets).get();
    final overrides = await db.select(db.categoryOverrides).get();

    final payload = {
      "version": 1,
      "exportedAt": DateTime.now().toIso8601String(),
      "categories": cats
          .map((c) => {
        "id": c.id,
        "name": c.name,
        "colorHex": c.colorHex,
      })
          .toList(),
      "transactions": txs
          .map((t) => {
        "id": t.id,
        "amount": t.amount,
        "note": t.note,
        "categoryId": t.categoryId,
        "date": t.date.toIso8601String(),
      })
          .toList(),
      "budgets": budgets
          .map((b) => {
        "id": b.id,
        "categoryId": b.categoryId,
        "year": b.year,
        "month": b.month,
        "amount": b.amount,
      })
          .toList(),
      "categoryOverrides": overrides
          .map((o) => {
        "id": o.id,
        "token": o.token,
        "categoryId": o.categoryId,
        "count": o.count,
      })
          .toList(),
    };

    return const JsonEncoder.withIndent("  ").convert(payload);
  }

  static Future<void> importJson(
      AppDatabase db,
      String jsonText, {
        bool replaceAll = false,
      }) async {
    final decoded = json.decode(jsonText);
    if (decoded is! Map) throw Exception("Geçersiz JSON formatı");

    final categories = (decoded["categories"] as List?) ?? const [];
    final transactions = (decoded["transactions"] as List?) ?? const [];
    final budgets = (decoded["budgets"] as List?) ?? const [];
    final overrides = (decoded["categoryOverrides"] as List?) ?? const [];

    await db.transaction(() async {
      if (replaceAll) {
        await db.delete(db.categoryOverrides).go();
        await db.delete(db.budgets).go();
        await db.delete(db.transactions).go();
        await db.delete(db.categories).go();
      }

      // ✅ customStatement: args içinde null serbest
      for (final c in categories) {
        if (c is! Map) continue;
        await db.customStatement(
          'INSERT OR REPLACE INTO categories (id, name, color_hex) VALUES (?, ?, ?)',
          [
            c["id"] as int,
            c["name"] as String,
            (c["colorHex"] as String?) ?? "#CCCCCC",
          ],
        );
      }

      for (final t in transactions) {
        if (t is! Map) continue;
        await db.customStatement(
          'INSERT OR REPLACE INTO transactions (id, amount, note, category_id, date) VALUES (?, ?, ?, ?, ?)',
          [
            t["id"] as int,
            (t["amount"] as num).toDouble(),
            t["note"] as String?, // ✅ null olabilir
            t["categoryId"] as int,
            DateTime.parse(t["date"] as String),
          ],
        );
      }

      for (final b in budgets) {
        if (b is! Map) continue;
        await db.customStatement(
          'INSERT OR REPLACE INTO budgets (id, category_id, year, month, amount) VALUES (?, ?, ?, ?, ?)',
          [
            b["id"] as int,
            b["categoryId"] as int,
            b["year"] as int,
            b["month"] as int,
            (b["amount"] as num).toDouble(),
          ],
        );
      }

      for (final o in overrides) {
        if (o is! Map) continue;
        await db.customStatement(
          'INSERT OR REPLACE INTO category_overrides (id, token, category_id, count) VALUES (?, ?, ?, ?)',
          [
            o["id"] as int,
            o["token"] as String,
            o["categoryId"] as int,
            (o["count"] as num?)?.toInt() ?? 1,
          ],
        );
      }
    });
  }
}
