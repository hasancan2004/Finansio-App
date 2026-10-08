import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../viewmodel/saving_goals_provider.dart';

class AddSavingGoalScreen extends ConsumerStatefulWidget {
  const AddSavingGoalScreen({super.key});

  @override
  ConsumerState<AddSavingGoalScreen> createState() => _AddSavingGoalScreenState();
}

class _AddSavingGoalScreenState extends ConsumerState<AddSavingGoalScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime? _targetDate;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _saveGoal() {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(amountText) ?? 0.0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir başlık ve tutar girin.')),
      );
      return;
    }

    ref.read(savingGoalsControllerProvider).addGoal(
      title: title,
      targetAmount: amount,
      targetDate: _targetDate,
      colorHex: '#3B82F6',
      iconName: 'savings',
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Kumbara'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Hedef Adı (Örn: Tatil, MacBook)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hedeflenen Tutar (₺)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Hedef Tarihi (İsteğe Bağlı)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _targetDate != null
                      ? DateFormat('dd.MM.yyyy').format(_targetDate!)
                      : 'Tarih Seçilmedi',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _targetDate != null ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveGoal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kumbarayı Oluştur', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
