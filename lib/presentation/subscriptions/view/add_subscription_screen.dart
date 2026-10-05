import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../viewmodel/subscriptions_provider.dart';

// ─────────────────────────────────────────────────────────────
//  Popüler abonelik servisleri için model
// ─────────────────────────────────────────────────────────────
class _PopularService {
  final String name;
  final IconData icon;
  final Color color;
  final double? suggestedPrice;

  const _PopularService({
    required this.name,
    required this.icon,
    required this.color,
    this.suggestedPrice,
  });
}

const _popularServices = [
  _PopularService(name: 'Netflix',         icon: Icons.movie_outlined,             color: Color(0xFFE50914), suggestedPrice: 199),
  _PopularService(name: 'Spotify',         icon: Icons.music_note_outlined,        color: Color(0xFF1DB954), suggestedPrice: 59),
  _PopularService(name: 'YouTube Premium', icon: Icons.play_circle_outline,        color: Color(0xFFFF0000), suggestedPrice: 80),
  _PopularService(name: 'Amazon Prime',    icon: Icons.local_shipping_outlined,    color: Color(0xFF00A8E1), suggestedPrice: 39),
  _PopularService(name: 'Apple iCloud',    icon: Icons.cloud_outlined,             color: Color(0xFF636366), suggestedPrice: 13),
  _PopularService(name: 'Disney+',         icon: Icons.castle_outlined,            color: Color(0xFF113CCF), suggestedPrice: 135),
  _PopularService(name: 'Exxen',           icon: Icons.live_tv_outlined,           color: Color(0xFFF6C800), suggestedPrice: 100),
  _PopularService(name: 'BluTV',           icon: Icons.smart_display_outlined,     color: Color(0xFF007BFF), suggestedPrice: 80),
  _PopularService(name: 'Spor Salonu',     icon: Icons.fitness_center_outlined,    color: Color(0xFFFF9800), suggestedPrice: 500),
  _PopularService(name: 'ChatGPT Plus',    icon: Icons.psychology_outlined,        color: Color(0xFF10A37F), suggestedPrice: 700),
  _PopularService(name: 'iCloud+',         icon: Icons.cloud_queue_outlined,       color: Color(0xFF3E82F7), suggestedPrice: 13),
  _PopularService(name: 'Xbox Game Pass',  icon: Icons.sports_esports_outlined,    color: Color(0xFF107C10), suggestedPrice: 250),
];

// ─────────────────────────────────────────────────────────────
//  Frekans seçenekleri
// ─────────────────────────────────────────────────────────────
class _FrequencyOption {
  final String key;
  final String label;
  final IconData icon;

  const _FrequencyOption({required this.key, required this.label, required this.icon});
}

const _frequencies = [
  _FrequencyOption(key: 'weekly',  label: 'Haftalık', icon: Icons.view_week_outlined),
  _FrequencyOption(key: 'monthly', label: 'Aylık',    icon: Icons.calendar_month_outlined),
  _FrequencyOption(key: 'daily',   label: 'Günlük',   icon: Icons.today_outlined),
];

// ─────────────────────────────────────────────────────────────
//  Ana Ekran Widget'ı
// ─────────────────────────────────────────────────────────────
class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({super.key});

  @override
  ConsumerState<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen>
    with SingleTickerProviderStateMixin {

  final _nameController   = TextEditingController();
  final _amountController = TextEditingController();

  String   _selectedFrequency = 'monthly';
  DateTime _startDate         = DateTime.now();
  int?     _selectedServiceIndex; // Hızlı seçim kartı index'i
  bool     _isSaving = false;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─────────────── Popüler servise tıklandığında ───────────────
  void _onServiceTap(int index) {
    final service = _popularServices[index];
    setState(() {
      _selectedServiceIndex = index;
      _nameController.text = service.name;
      if (service.suggestedPrice != null) {
        _amountController.text = service.suggestedPrice!.toStringAsFixed(0);
      }
    });
  }

  // ─────────────── Tarih seçici ───────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'Abonelik Başlangıç Tarihi',
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  // ─────────────── Kaydet ───────────────
  Future<void> _saveSubscription() async {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(amountText) ?? 0.0;

    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen geçerli bir abonelik adı ve tutar girin.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(subscriptionsControllerProvider).addSubscription(
        name: name,
        amount: amount,
        frequency: _selectedFrequency,
        startDate: _startDate,
      );

      if (!mounted) return;

      // Başarı animasyonu ile geri dön
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('"$name" aboneliği eklendi!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  // ─────────────── Frekans etiketi ───────────────
  String _frequencyLabel(String key) {
    switch (key) {
      case 'weekly':  return 'Haftalık';
      case 'monthly': return 'Aylık';
      case 'daily':   return 'Günlük';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yeni Abonelik',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════════════════════════════
              //  BÖLÜM 1: Popüler Servisler (Hızlı Seçim)
              // ═══════════════════════════════════════════
              _buildSectionTitle(theme, cs, Icons.star_outline, 'Popüler Servisler'),
              const SizedBox(height: 8),

              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularServices.length,
                  itemBuilder: (context, index) {
                    final service = _popularServices[index];
                    final isSelected = _selectedServiceIndex == index;

                    return Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: index == _popularServices.length - 1 ? 0 : 4,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _onServiceTap(index),
                            child: Container(
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isSelected
                                    ? service.color.withOpacity(isDark ? 0.25 : 0.15)
                                    : cs.surfaceContainerHighest.withOpacity(0.5),
                                border: Border.all(
                                  color: isSelected
                                      ? service.color.withOpacity(0.8)
                                      : cs.outlineVariant.withOpacity(0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: service.color.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? service.color.withOpacity(0.2)
                                          : service.color.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      service.icon,
                                      size: 22,
                                      color: isSelected
                                          ? service.color
                                          : service.color.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    service.name.length > 10
                                        ? '${service.name.substring(0, 9)}…'
                                        : service.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? service.color
                                          : cs.onSurfaceVariant,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ═══════════════════════════════════════════
              //  BÖLÜM 2: Abonelik Bilgileri Formu
              // ═══════════════════════════════════════════
              _buildSectionTitle(theme, cs, Icons.edit_note_outlined, 'Abonelik Bilgileri'),
              const SizedBox(height: 12),

              // Servis Adı
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Abonelik Adı',
                  hintText: 'Ör: Netflix, Spotify, MacFit...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.subscriptions_outlined),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Tutar
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Aylık Tutar (₺)',
                  hintText: '0.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  suffixText: '₺',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // ═══════════════════════════════════════════
              //  BÖLÜM 3: Ödeme Sıklığı
              // ═══════════════════════════════════════════
              _buildSectionTitle(theme, cs, Icons.repeat_outlined, 'Ödeme Sıklığı'),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: _frequencies.map((freq) {
                    final isSelected = _selectedFrequency == freq.key;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  freq.icon,
                                  size: 16,
                                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(freq.label),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedFrequency = freq.key);
                            },
                            selectedColor: cs.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(
                              color: isSelected ? cs.primary : Colors.transparent,
                            ),
                            showCheckmark: false,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // ═══════════════════════════════════════════
              //  BÖLÜM 4: Başlangıç Tarihi
              // ═══════════════════════════════════════════
              _buildSectionTitle(theme, cs, Icons.calendar_today_outlined, 'Başlangıç Tarihi'),
              const SizedBox(height: 12),

              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_outlined, color: cs.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'İlk Ödeme Tarihi',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMMM yyyy', 'tr_TR').format(_startDate),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ═══════════════════════════════════════════
              //  BÖLÜM 5: Özet Kartı
              // ═══════════════════════════════════════════
              if (_nameController.text.trim().isNotEmpty) ...[
                _buildSummaryCard(theme, cs, isDark),
                const SizedBox(height: 24),
              ],

              // ═══════════════════════════════════════════
              //  KAYDET BUTONU
              // ═══════════════════════════════════════════
              FilledButton(
                onPressed: _isSaving ? null : _saveSubscription,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: _selectedServiceIndex != null
                      ? _popularServices[_selectedServiceIndex!].color
                      : cs.primary,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Aboneliği Kaydet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── Bölüm Başlığı ───────────────
  Widget _buildSectionTitle(ThemeData theme, ColorScheme cs, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ─────────────── Özet Kartı ───────────────
  Widget _buildSummaryCard(ThemeData theme, ColorScheme cs, bool isDark) {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(amountText) ?? 0.0;

    Color accentColor = cs.primary;
    if (_selectedServiceIndex != null) {
      accentColor = _popularServices[_selectedServiceIndex!].color;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(isDark ? 0.20 : 0.10),
            accentColor.withOpacity(isDark ? 0.08 : 0.04),
          ],
        ),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_outlined, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Abonelik Özeti',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRow(theme, cs, 'Servis', name),
          if (amount > 0) _summaryRow(theme, cs, 'Tutar', '${NumberFormat("#,##0", "tr_TR").format(amount)} ₺'),
          _summaryRow(theme, cs, 'Sıklık', _frequencyLabel(_selectedFrequency)),
          _summaryRow(theme, cs, 'Başlangıç', DateFormat('dd.MM.yyyy').format(_startDate)),
        ],
      ),
    );
  }

  Widget _summaryRow(ThemeData theme, ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
