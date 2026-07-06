import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'dashboard_screen.dart' show money;

const _okColor = Color(0xFF46F1C5);
const _palette = [
  Color(0xFF6EA8FE),
  Color(0xFF46F1C5),
  Color(0xFFB68CF0),
  Color(0xFFF0B36B),
  Color(0xFFEC9BC4),
  Color(0xFF5FD4C2),
];
const _icons = [
  Icons.flight,
  Icons.shield_outlined,
  Icons.laptop_mac,
  Icons.home_outlined,
  Icons.directions_car_filled_outlined,
  Icons.card_giftcard,
];

/// Tasarruf Hedefleri — premium: özet kartı, renkli hedef kartları, katkı/ekle
/// alt sayfaları, sola kaydır→sil. Renk/ikon indekse göre atanır.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late Future<List<GoalModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.getGoals();
  }

  void _refresh() => setState(() => _future = ApiClient.instance.getGoals());

  Color _color(int i) => _palette[i % _palette.length];
  IconData _icon(int i) => _icons[i % _icons.length];

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      floatingActionButton: FutureBuilder<List<GoalModel>>(
        future: _future,
        builder: (context, snap) {
          if ((snap.data ?? []).isEmpty) return const SizedBox.shrink();
          return Press(
            onTap: _openAdd,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: Icon(Icons.add, color: AppColors.onPrimary, size: 26),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        color: AppColors.onSurface,
        backgroundColor: AppColors.surface,
        child: FutureBuilder<List<GoalModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: AppColors.onSurface));
            }
            final goals = snap.data ?? [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
              children: [
                Rise(child: _header(isDark, goals.length)),
                const SizedBox(height: 22),
                if (goals.isEmpty)
                  _empty()
                else ...[
                  Rise(delayMs: 40, child: _summary(goals)),
                  const SizedBox(height: 20),
                  for (var i = 0; i < goals.length; i++)
                    Rise(delayMs: 80 + i * 30, child: _goalCard(goals[i], i)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(bool isDark, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Press(
                onTap: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: Icon(Icons.arrow_back,
                      size: 22, color: AppColors.onSurface),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tasarruf Hedefleri',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1,
                            color: AppColors.onSurface)),
                    const SizedBox(height: 6),
                    Text(count > 0 ? '$count aktif hedef' : 'hedef yok',
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Press(
          onTap: () => themeModeNotifier.value =
              isDark ? ThemeMode.light : ThemeMode.dark,
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

  Widget _summary(List<GoalModel> goals) {
    final saved = goals.fold(
        0.0, (s, g) => s + (g.currentAmount.clamp(0, g.targetAmount)));
    final target = goals.fold(0.0, (s, g) => s + g.targetAmount);
    final done = goals.where((g) => g.progress >= 1).length;
    final pct = target == 0 ? 0.0 : saved / target;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOPLAM BİRİKİM',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.onSurfaceVariant)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: _okColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99)),
                child: Text('$done tamamlandı',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _okColor,
                        fontFeatures: kTnum)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(saved),
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: AppColors.onSurface,
                      fontFeatures: kTnum)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ ${money(target)}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.outline,
                        fontFeatures: kTnum)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct.clamp(0, 1).toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 9,
                backgroundColor: AppColors.surfaceContainer,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(GoalModel g, int index) {
    final color = _color(index);
    final complete = g.progress >= 1;
    final barColor = complete ? _okColor : color;
    final pct = (g.progress * 100).clamp(0, 100).toInt();

    return Dismissible(
      key: ValueKey(g.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_outline, color: Colors.white, size: 20),
            SizedBox(height: 3),
            Text('Sil',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(g),
      onDismissed: (_) async {
        await ApiClient.instance.deleteGoal(g.id);
        _refresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(_icon(index), size: 20, color: barColor),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(g.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface)),
                          ),
                          if (complete) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: _okColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(99)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check,
                                      size: 11, color: _okColor),
                                  const SizedBox(width: 3),
                                  Text('Tamamlandı',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _okColor)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(money(g.currentAmount.clamp(0, g.targetAmount)),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                  fontFeatures: kTnum)),
                          Text(' / ${money(g.targetAmount)}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.outline,
                                  fontFeatures: kTnum)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('%$pct',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: complete ? _okColor : AppColors.onSurface,
                        fontFeatures: kTnum)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: g.progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceContainer,
                  color: barColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (complete)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _okColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('Hedefe ulaşıldı 🎉',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _okColor)),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kalan',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.outline)),
                      Text(money(g.remaining),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              fontFeatures: kTnum)),
                    ],
                  ),
                  Press(
                    onTap: () => _openContribute(g, color),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.surfaceContainerHigh)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 15, color: color),
                          const SizedBox(width: 6),
                          Text('Katkı Ekle',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.glassBorder)),
            child: Icon(Icons.savings_outlined,
                size: 32, color: AppColors.outline),
          ),
          const SizedBox(height: 18),
          Text('Henüz hedefin yok',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const SizedBox(height: 6),
          Text(
              'İlk tasarruf hedefini oluştur ve birikimlerini takip etmeye başla.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.outline)),
          const SizedBox(height: 20),
          Press(
            onTap: _openAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 17, color: AppColors.onPrimary),
                  const SizedBox(width: 7),
                  Text('İlk Hedefini Ekle',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Alt sayfa kabuğu ----
  Future<void> _sheet(Widget Function(BuildContext, StateSetter) builder) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                builder(ctx, setSheet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetTitle(BuildContext ctx, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface)),
          ),
          Press(
            onTap: () => Navigator.pop(ctx),
            child: Icon(Icons.close, size: 22, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: AppColors.outline)),
      );

  Widget _inputBox({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: child,
      );

  Widget _primaryButton(String label, VoidCallback onTap) => Press(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary)),
        ),
      );

  Future<void> _openAdd() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    await _sheet((ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle(ctx, 'Yeni Hedef'),
            _fieldLabel('HEDEF ADI'),
            _inputBox(
              child: TextField(
                controller: nameCtrl,
                style: TextStyle(fontSize: 14, color: AppColors.onSurface),
                decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'örn. Yeni Telefon',
                    hintStyle:
                        TextStyle(color: AppColors.outline, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 18),
            _fieldLabel('HEDEF TUTAR (${currencyNotifier.value})'),
            _inputBox(
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
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface),
                      decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '0'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _primaryButton('Hedef Oluştur', () async {
              final name = nameCtrl.text.trim();
              final enteredTarget =
                  double.tryParse(targetCtrl.text.replaceAll(',', '.'));
              if (name.isEmpty || enteredTarget == null || enteredTarget <= 0) return;
              final targetInTry = CurrencyService.convertToTry(enteredTarget, currencyNotifier.value);
              await ApiClient.instance.createGoal(name, targetInTry);
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            }),
          ],
        ));
  }

  Future<void> _openContribute(GoalModel g, Color color) async {
    final amtCtrl = TextEditingController();
    final rate = CurrencyService.rates[currencyNotifier.value] ?? 1.0;
    final remain = g.remaining * rate;
    final quick = [500.0, 1000.0, 2500.0]
        .map((q) => q * rate)
        .where((q) => q <= remain)
        .toList();
    if (remain > 0 && !quick.contains(remain)) quick.add(remain);

    await _sheet((ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle(ctx, '${g.title} — Katkı Ekle'),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                  'Kalan ${money(g.remaining)} · Hedef ${money(g.targetAmount)}',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.outline,
                      fontFeatures: kTnum)),
            ),
            _fieldLabel('TUTAR (${currencyNotifier.value})'),
            _inputBox(
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
                      controller: amtCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface),
                      decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '0'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quick
                  .map((q) => Press(
                        onTap: () =>
                            setSheet(() => amtCtrl.text = q.toStringAsFixed(0)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.surfaceContainerHigh)),
                          child: Text('+${currencyNotifier.value}${q.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                  fontFeatures: kTnum)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            _primaryButton('Ekle', () async {
              final enteredAmt = double.tryParse(amtCtrl.text.replaceAll(',', '.'));
              if (enteredAmt == null || enteredAmt <= 0) return;
              final amtInTry = CurrencyService.convertToTry(enteredAmt, currencyNotifier.value);
              await ApiClient.instance.contributeGoal(g.id, amtInTry);
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            }),
          ],
        ));
  }

  Future<bool> _confirmDelete(GoalModel g) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.glassBorder)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.14),
                        shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline,
                        color: AppColors.error, size: 22),
                  ),
                  const SizedBox(height: 14),
                  Text('Hedefi sil?',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 6),
                  Text('"${g.title}" hedefi ve birikimi silinecek.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Press(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                    color: AppColors.surfaceContainerHigh)),
                            child: Text('Vazgeç',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Press(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(13)),
                            child: const Text('Sil',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }
}
