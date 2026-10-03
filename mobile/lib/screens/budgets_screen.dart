import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'dashboard_screen.dart' show categoryColor, categoryIcon, money;

const _okColor = Color(0xFF46F1C5);

/// Bütçe ekranı — premium: toplam bütçe kartı, kategori kartları, alttan açılan
/// ekle/düzenle/sil sayfası. Gerçek backend'e bağlı.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => BudgetsScreenState();
}

class BudgetsScreenState extends State<BudgetsScreen> {
  late Future<List<BudgetModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.getBudgets();
  }

  void refresh() => setState(() { _future = ApiClient.instance.getBudgets(); });

  Color _statusColor(double pct) {
    if (pct >= 90) return AppColors.error;
    if (pct >= 75) return AppColors.warn;
    return _okColor;
  }

  ({String label, Color color}) _status(double pct) {
    if (pct >= 100) return (label: 'Aşıldı', color: AppColors.error);
    if (pct >= 90) return (label: 'Kritik', color: AppColors.error);
    if (pct >= 75) return (label: 'Dikkat', color: AppColors.warn);
    return (label: 'Yolunda', color: _okColor);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => refresh(),
        color: AppColors.onSurface,
        backgroundColor: AppColors.surface,
        child: FutureBuilder<List<BudgetModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: AppColors.onSurface));
            }
            final budgets = snap.data ?? [];
            final categoryBudgets = budgets.where((b) => b.category != 'Toplam').toList();
            final totalBudget = budgets.firstWhere(
              (b) => b.category == 'Toplam',
              orElse: () => BudgetModel(id: -1, category: 'Toplam', monthlyLimit: 0.0, spent: 0.0),
            );

            final spent = totalBudget.id == -1 
                ? categoryBudgets.fold(0.0, (s, b) => s + b.spent)
                : totalBudget.spent;
            final limit = totalBudget.monthlyLimit;

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
              children: [
                Rise(child: _header(isDark)),
                const SizedBox(height: 22),
                Rise(delayMs: 40, child: _totalCard(limit, spent, totalBudget, budgets)),
                const SizedBox(height: 22),
                Rise(
                  delayMs: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Kategori Bütçeleri',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface)),
                      Press(
                        onTap: () => _openSheet(budgets, null),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text('Bütçe',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (categoryBudgets.isEmpty)
                  Rise(
                    delayMs: 120,
                    child: _card(
                      child: Text('Henüz bütçe yok. "Bütçe" ile ekle.',
                          style:
                              TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                  )
                else
                  for (var i = 0; i < categoryBudgets.length; i++)
                    Rise(
                        delayMs: 100 + i * 30,
                        child: _budgetCard(categoryBudgets[i], budgets)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: child,
    );
  }

  Widget _header(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bütçe',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1,
                    color: AppColors.onSurface)),
            const SizedBox(height: 6),
            Text(
                '${DateFormat('MMMM yyyy', 'tr_TR').format(DateTime.now())} · aylık limitler',
                style: TextStyle(fontSize: 12.5, color: AppColors.outline)),
          ],
        ),
        Press(
          onTap: toggleThemeMode,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceContainer)),
            child: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 18,
                color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _totalCard(double limit, double spent, BudgetModel totalBudget, List<BudgetModel> all) {
    final remain = limit - spent;
    final pct = limit == 0 ? 0.0 : (spent / limit * 100);
    final clamped = pct.clamp(0, 100).toDouble();
    final color = _statusColor(pct);
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = lastDay - now.day;

    return Press(
      onTap: () => _openSheet(all, totalBudget.id == -1 ? null : totalBudget, isTotal: true),
      child: _card(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(limit == 0 ? 'AYLIK TOPLAM BÜTÇE (LİMİT BELİRLE)' : 'TOPLAM AYLIK BÜTÇE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: AppColors.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99)),
                  child: Text(limit == 0 ? 'Limit belirlenmedi' : '%${pct.toStringAsFixed(0)} kullanıldı',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFeatures: kTnum)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KALAN',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                            color: AppColors.outline)),
                    const SizedBox(height: 5),
                    Text(money(remain),
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: remain < 0
                                ? AppColors.error
                                : AppColors.onSurface,
                            fontFeatures: kTnum)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LİMİT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                            color: AppColors.outline)),
                    const SizedBox(height: 5),
                    Text(money(limit),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                            fontFeatures: kTnum)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: clamped / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceContainer,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${money(spent)} harcandı',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.outline,
                        fontFeatures: kTnum)),
                Text('Ay sonuna $daysLeft gün',
                    style: TextStyle(fontSize: 12, color: AppColors.outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetCard(BudgetModel b, List<BudgetModel> all) {
    final pct = b.monthlyLimit == 0 ? 0.0 : (b.spent / b.monthlyLimit * 100);
    final color = _statusColor(pct);
    final st = _status(pct);
    final cc = categoryColor(b.category);
    return Press(
      onTap: () => _openSheet(all, b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: cc.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(categoryIcon(b.category), size: 19, color: cc),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(b.category,
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface)),
                          const SizedBox(width: 8),
                          Text(st.label.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: st.color)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(money(b.spent),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                  fontFeatures: kTnum)),
                          Text(' / ${money(b.monthlyLimit)}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.outline,
                                  fontFeatures: kTnum)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('%${pct.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: kTnum)),
              ],
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (pct / 100).clamp(0, 1)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: AppColors.surfaceContainer,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Ekle / Düzenle / Sil alt sayfası ----
  Future<void> _openSheet(List<BudgetModel> all, BudgetModel? editing, {bool isTotal = false}) async {
    final usedCats = all.map((b) => b.category).toSet();
    final available = isTotal 
        ? ['Toplam']
        : (editing != null
            ? [editing.category]
            : kCategories.where((c) => !usedCats.contains(c)).toList());
    if (available.isEmpty && !isTotal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tüm kategoriler için bütçe tanımlı.')));
      return;
    }

    String chosen = isTotal ? 'Toplam' : (editing?.category ?? available.first);
    final initialLimit = editing != null && editing.monthlyLimit > 0
        ? CurrencyService.convertFromTry(editing.monthlyLimit, currencyNotifier.value)
        : 0.0;
    final limitCtrl = TextEditingController(
        text: initialLimit > 0 ? initialLimit.toStringAsFixed(0) : '');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isTotal
                            ? (editing != null && editing.monthlyLimit > 0 ? 'Toplam Bütçeyi Düzenle' : 'Toplam Bütçe Belirle')
                            : (editing != null ? '${editing.category} Bütçesi' : 'Yeni Bütçe'),
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface)),
                        Press(
                          onTap: () => Navigator.pop(ctx),
                          child: Icon(Icons.close,
                              size: 22, color: AppColors.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (!isTotal) ...[
                      Text('KATEGORİ',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: AppColors.outline)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: available.map((c) {
                          final on = c == chosen;
                          final cc = categoryColor(c);
                          return GestureDetector(
                            onTap: editing != null
                                ? null
                                : () => setSheet(() => chosen = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 8),
                              decoration: BoxDecoration(
                                color: on
                                    ? cc.withValues(alpha: 0.16)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                    color: on
                                        ? Colors.transparent
                                        : AppColors.surfaceContainerHigh),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                        color: cc, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(c,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: on
                                              ? cc
                                              : AppColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text('AYLIK LİMİT (${currencyNotifier.value})',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: AppColors.outline)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Text(currencyNotifier.value,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: limitCtrl,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface),
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: '0',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (editing != null) ...[
                          Press(
                            onTap: () async {
                              await ApiClient.instance.deleteBudget(editing.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                              refresh();
                            },
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.surfaceContainerHigh)),
                              child: Icon(Icons.delete_outline,
                                  color: AppColors.error, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Press(
                            onTap: () async {
                              final enteredLim = double.tryParse(
                                  limitCtrl.text.replaceAll(',', '.'));
                              if (enteredLim == null || enteredLim <= 0) return;
                              final limInTry = CurrencyService.convertToTry(enteredLim, currencyNotifier.value);
                              await ApiClient.instance
                                  .upsertBudget(chosen, limInTry);
                              if (ctx.mounted) Navigator.pop(ctx);
                              refresh();
                            },
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Text(
                                  editing != null ? 'Kaydet' : 'Bütçe Ekle',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onPrimary)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
