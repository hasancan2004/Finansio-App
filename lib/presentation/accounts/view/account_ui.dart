import 'package:flutter/material.dart';

import '../../../domain/models/account.dart';

/// Hesap modülü için UI yardımcıları (ikon ve renk eşlemeleri).
class AccountUi {
  const AccountUi._();

  static IconData iconForType(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.bank:
        return Icons.account_balance_outlined;
      case AccountType.creditCard:
        return Icons.credit_card;
    }
  }

  static IconData iconFor(AccountSummary account) {
    return iconMapping[account.iconName] ?? iconForType(account.type);
  }

  static const Map<String, IconData> iconMapping = {
    'wallet': Icons.account_balance_wallet_outlined,
    'cash': Icons.payments_outlined,
    'bank': Icons.account_balance_outlined,
    'card': Icons.credit_card,
    'savings': Icons.savings_outlined,
    'business': Icons.business_center_outlined,
  };

  static const List<String> iconKeys = [
    'wallet',
    'cash',
    'bank',
    'card',
    'savings',
    'business',
  ];

  static Color hexToColor(String hex) {
    final v = hex.replaceAll('#', '');
    final value = int.tryParse(v.length == 6 ? 'FF$v' : v, radix: 16) ?? 0xFF3B82F6;
    return Color(value);
  }

  static const List<String> colorPalette = [
    '#22C55E',
    '#3B82F6',
    '#6366F1',
    '#EF4444',
    '#F59E0B',
    '#8B5CF6',
    '#EC4899',
    '#14B8A6',
    '#64748B',
  ];

  static List<Color> paletteColors() =>
      colorPalette.map(hexToColor).toList();
}
