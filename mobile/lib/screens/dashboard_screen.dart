import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'goals_screen.dart';
import 'chat_screen.dart';

final tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _grp = NumberFormat('#,##0', 'tr_TR');

/// Premium para gösterimi: işaret + ₺ + binlik ayraç, küsurat varsa 2 hane.
String money(double v, {bool showSign = false}) {
  final neg = v < 0;
  final abs = v.abs();
  final whole = abs.truncate();
  final cents = ((abs - whole) * 100).round();
  final sign = neg ? '−' : (showSign ? '+' : '');
  final base = '$sign₺${_grp.format(whole)}';
  return cents == 0 ? base : '$base,${cents.toString().padLeft(2, '0')}';
}

/// Kategori -> ikon (diğer ekranlar da kullanır).
IconData categoryIcon(String c) => switch (c) {
      'Yemek' => Icons.restaurant,
      'Ulaşım' => Icons.directions_car,
      'Faturalar' => Icons.receipt_long,
      'Eğlence' => Icons.movie,
      'Sağlık' => Icons.medical_services,
      'Eğitim' => Icons.school,
      'Alışveriş' => Icons.shopping_bag,
      _ => Icons.more_horiz,
    };

/// Kategori -> renk (liste ikonları için; diğer ekranlar kullanır).
Color categoryColor(String c) => switch (c) {
      'Yemek' => const Color(0xFF46F1C5),
      'Ulaşım' => const Color(0xFF6EA8FE),
      'Faturalar' => const Color(0xFFB68CF0),
      'Eğlence' => const Color(0xFFF0B36B),
      'Sağlık' => const Color(0xFFF2766B),
      'Eğitim' => const Color(0xFF5FD4C2),
      'Alışveriş' => const Color(0xFFEC9BC4),
      _ => const Color(0xFF8A958F),
    };

class _DashData {
  final List<TransactionModel> txs;
  final List<GoalModel> goals;
  final String name;
  _DashData(this.txs, this.goals, this.name);
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final api = ApiClient.instance;
    final r = await Future.wait([
      api.getTransactions(),
      api.getGoals(),
      api.getMe(),
    ]);
    final me = r[2] as ({String email, String displayName});
    final name = me.displayName.isNotEmpty ? me.displayName : 'Kullanıcı';
    return _DashData(
        r[0] as List<TransactionModel>, r[1] as List<GoalModel>, name);
  }

  void refresh() => setState(() { _future = _load(); });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => refresh(),
        color: AppColors.onSurface,
        backgroundColor: AppColors.surface,
        child: FutureBuilder<_DashData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: AppColors.onSurface));
            }
            if (snap.hasError) return _errorState(snap.error.toString());
            final d = snap.data!;
            final income = d.txs
                .where((t) => t.type == 'income')
                .fold(0.0, (s, t) => s + t.amount);
            final expense = d.txs
                .where((t) => t.type == 'expense')
                .fold(0.0, (s, t) => s + t.amount);

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              children: [
                Rise(child: _header(d.name)),
                const SizedBox(height: 44),
                Rise(delayMs: 40, child: _balance(income - expense)),
                const SizedBox(height: 22),
                Rise(delayMs: 60, child: _incomeExpense(income, expense)),
                const SizedBox(height: 40),
                if (d.goals.isNotEmpty)
                  Rise(delayMs: 90, child: _goalLine(d.goals.first)),
                if (d.goals.isNotEmpty) const SizedBox(height: 40),
                Rise(delayMs: 120, child: _spending(d.txs, expense)),
                const SizedBox(height: 40),
                Rise(delayMs: 150, child: _recent(d.txs)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Başlık ----
  Widget _header(String name) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                    color: AppColors.outline)),
            const SizedBox(height: 2),
            Text(name,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.onSurface)),
          ],
        ),
        Row(
          children: [
            Press(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceContainer),
                ),
                child: Icon(Icons.psychology_outlined,
                    size: 18, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            Press(
              onTap: () {
                themeModeNotifier.value =
                    isDark ? ThemeMode.light : ThemeMode.dark;
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceContainer),
                ),
                child: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 18, color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Bakiye (kart yok) ----
  Widget _balance(double balance) {
    final neg = balance < 0;
    final abs = balance.abs();
    final whole = abs.truncate();
    final cents = ((abs - whole) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TOPLAM BAKİYE',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
                color: AppColors.outline)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${neg ? '−' : ''}₺${_grp.format(whole)}',
                style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1.5,
                    color: AppColors.onSurface,
                    fontFeatures: kTnum)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Text(',${cents.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outline,
                      fontFeatures: kTnum)),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Gelir / Gider satırı ----
  Widget _incomeExpense(double income, double expense) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
          bottom: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _ieCell('GELİR', income)),
            Container(width: 1, color: AppColors.glassBorder),
            Expanded(child: _ieCell('GİDER', expense, padLeft: true)),
          ],
        ),
      ),
    );
  }

  Widget _ieCell(String label, double value, {bool padLeft = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padLeft ? 20 : 0, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: AppColors.outline)),
          const SizedBox(height: 6),
          Text(money(value),
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  fontFeatures: kTnum)),
        ],
      ),
    );
  }

  // ---- Tasarruf hedefi (tek satır) ----
  Widget _goalLine(GoalModel g) {
    return Press(
      onTap: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GoalsScreen()));
        refresh();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(g.title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              Text('${money(g.currentAmount)} / ${money(g.targetAmount)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.outline,
                      fontFeatures: kTnum)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: g.progress.clamp(0, 1)),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainer,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text('%${(g.progress * 100).toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      fontFeatures: kTnum)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Harcama dağılımı (monokrom donut) ----
  Widget _spending(List<TransactionModel> txs, double expense) {
    final byCat = <String, double>{};
    for (final t in txs.where((t) => t.type == 'expense')) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(4).toList();

    // Kategori renkleriyle canlı donut (diğer ekranlarla tutarlı).
    Color ramp(int i) => categoryColor(top[i].key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Harcama Dağılımı',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
            Text(DateFormat.MMMM('tr_TR').format(DateTime.now()),
                style: TextStyle(fontSize: 12, color: AppColors.outline)),
          ],
        ),
        const SizedBox(height: 24),
        if (entries.isEmpty)
          Text('Gider verisi yok',
              style: TextStyle(color: AppColors.onSurfaceVariant))
        else
          Row(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 40,
                        sections: [
                          for (var i = 0; i < top.length; i++)
                            PieChartSectionData(
                              value: top[i].value,
                              color: ramp(i),
                              radius: 12,
                              showTitle: false,
                            ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 700),
                    ),
                    Text(money(expense),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            fontFeatures: kTnum)),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < top.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: ramp(i),
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(top[i].key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.onSurfaceVariant)),
                            ),
                            Text(
                                '%${(expense == 0 ? 0 : top[i].value / expense * 100).toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                    fontFeatures: kTnum)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---- Son işlemler (düz liste) ----
  Widget _recent(List<TransactionModel> txs) {
    final list = txs.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Son İşlemler',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface)),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Henüz işlem yok. + ile ekle.',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          )
        else
          for (var i = 0; i < list.length; i++) _txRow(list[i], i < list.length - 1),
      ],
    );
  }

  Widget _txRow(TransactionModel t, bool border) {
    final isIncome = t.type == 'income';
    return Press(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: border
              ? Border(bottom: BorderSide(color: AppColors.glassBorder))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: categoryColor(t.category).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(categoryIcon(t.category),
                  size: 18, color: categoryColor(t.category)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.note.isEmpty ? t.category : t.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text('${t.category} · ${t.occurredOn}',
                      style: TextStyle(fontSize: 12, color: AppColors.outline)),
                ],
              ),
            ),
            Text('${isIncome ? '+' : '−'}${money(t.amount)}',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isIncome ? AppColors.primary : AppColors.onSurface,
                    fontFeatures: kTnum)),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String msg) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.cloud_off, color: AppColors.outline, size: 48),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text('Backend\'e bağlanılamadı.\n$msg',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: TextButton(onPressed: refresh, child: const Text('Tekrar dene'))),
      ],
    );
  }
}
