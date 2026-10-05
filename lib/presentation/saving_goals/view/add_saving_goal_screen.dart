import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodel/saving_goals_provider.dart';

class AddSavingGoalScreen extends ConsumerStatefulWidget {
  const AddSavingGoalScreen({super.key});

  @override
  ConsumerState<AddSavingGoalScreen> createState() => _AddSavingGoalScreenState();
}

class _AddSavingGoalScreenState extends ConsumerState<AddSavingGoalScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
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

    // Provider üzerinden veritabanına kaydediyoruz
    ref.read(savingGoalsControllerProvider).addGoal(
      title: title,
      targetAmount: amount,
      colorHex: '#3B82F6', // Şimdilik standart mavi atıyoruz, ileride renk seçici koyarız
      iconName: 'savings',
    );

    Navigator.pop(context); // Kaydedince geri dön
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 16), // SafeArea için biraz boşluk
          ],
        ),
      ),
    );
  }
}