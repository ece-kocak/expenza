import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'dashboard_screen.dart' show categoryColor, categoryIcon, money;

const _forecastColor = Color(0xFF6EA8FE);
const _okColor = Color(0xFF46F1C5);

/// Analitik (İP-4) — premium: tahmin kartı, harcama trendi (gerçekleşen + tahmin),
/// harcama hızı, olağandışı harcamalar, en çok harcanan kategoriler.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final api = ApiClient.instance;
    final r = await Future.wait([
      api.getForecast(),
      api.getAnomalies(),
      api.getTransactions(),
    ]);
    return _Data(r[0] as ForecastModel, r[1] as List<AnomalyModel>,
        r[2] as List<TransactionModel>);
  }

  String _monthShort(String yyyyMm) {
    const m = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    final p = yyyyMm.split('-');
    final i = p.length == 2 ? (int.tryParse(p[1]) ?? 1) : 1;
    return (i >= 1 && i <= 12) ? m[i - 1] : yyyyMm;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _future = _load()),
        color: AppColors.onSurface,
        backgroundColor: AppColors.surface,
        child: FutureBuilder<_Data>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: AppColors.onSurface));
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(
                    child: Text('Veri alınamadı\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.onSurfaceVariant))),
              ]);
            }
            final d = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
              children: [
                Rise(child: _header(isDark)),
                const SizedBox(height: 24),
                Rise(delayMs: 40, child: _forecastCard(d.forecast)),
                const SizedBox(height: 14),
                Rise(delayMs: 80, child: _trendCard(d.forecast)),
                const SizedBox(height: 14),
                Rise(delayMs: 120, child: _velocityCard(d.forecast)),
                const SizedBox(height: 14),
                Rise(delayMs: 160, child: _anomaliesSection(d.anomalies)),
                const SizedBox(height: 14),
                Rise(delayMs: 200, child: _topCategories(d.txs)),
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
            Text('Analitik',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1,
                    color: AppColors.onSurface)),
            const SizedBox(height: 6),
            Text(
                '${DateFormat('MMMM yyyy', 'tr_TR').format(DateTime.now())} · içgörüler',
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

  // ---- Tahmin kartı ----
  Widget _forecastCard(ForecastModel f) {
    final last = f.history.isNotEmpty ? f.history.last.total : 0.0;
    final hasChange = last > 0;
    final pct = hasChange ? (f.nextMonthPrediction - last) / last * 100 : 0.0;
    final up = pct >= 0;
    return _card(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: _forecastColor),
              const SizedBox(width: 8),
              Text('GELECEK AY TAHMİNİ',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(f.nextMonthPrediction),
                  style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: AppColors.onSurface,
                      fontFeatures: kTnum)),
              if (hasChange) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('${up ? '↑' : '↓'} %${pct.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: up ? AppColors.error : _okColor,
                          fontFeatures: kTnum)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
              hasChange
                  ? 'Geçen aya göre tahmini ${up ? 'artış' : 'azalış'}'
                  : 'Mevcut verilere göre tahmin',
              style: TextStyle(fontSize: 12.5, color: AppColors.outline)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.glassBorder))),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                      child: _miniCol(
                          'AY SONU PROJEKSİYONU', f.projectedMonthEnd)),
                  Container(width: 1, color: AppColors.glassBorder),
                  Expanded(
                      child: _miniCol('BU ANA DEK', f.currentMonthSpent,
                          padLeft: true)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCol(String label, double value, {bool padLeft = false}) {
    return Padding(
      padding: EdgeInsets.only(left: padLeft ? 18 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  color: AppColors.outline)),
          const SizedBox(height: 5),
          Text(money(value),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  fontFeatures: kTnum)),
        ],
      ),
    );
  }

  // ---- Harcama trendi ----
  Widget _trendCard(ForecastModel f) {
    final solid = <double>[...f.history.map((h) => h.total), f.projectedMonthEnd];
    final labels = <String>[
      ...f.history.map((h) => _monthShort(h.month)),
      'Bu ay',
      'Tahmin'
    ];
    if (solid.length < 2) return const SizedBox.shrink();
    final lastIdx = solid.length - 1; // current month (last solid)
    final all = [...solid, f.nextMonthPrediction];
    final maxV = all.reduce((a, b) => a > b ? a : b) * 1.12;
    final minV = all.reduce((a, b) => a < b ? a : b) * 0.85;

    final solidSpots = [
      for (var i = 0; i < solid.length; i++) FlSpot(i.toDouble(), solid[i])
    ];
    final dashedSpots = [
      FlSpot(lastIdx.toDouble(), solid[lastIdx]),
      FlSpot((lastIdx + 1).toDouble(), f.nextMonthPrediction),
    ];

    return _card(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Harcama Trendi',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              Text('Geçmiş + tahmin',
                  style: TextStyle(fontSize: 11.5, color: AppColors.outline)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: minV,
                maxY: maxV,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxV - minV) / 2,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.glassBorder, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final isForecast = i == labels.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i],
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isForecast
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isForecast
                                      ? _forecastColor
                                      : AppColors.outline)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  // Gerçekleşen (düz)
                  LineChartBarData(
                    spots: solidSpots,
                    isCurved: true,
                    color: AppColors.onSurface,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (s, _) => s.x.toInt() == lastIdx,
                      getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.onSurface,
                          strokeWidth: 0),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                  // Tahmin (kesikli)
                  LineChartBarData(
                    spots: dashedSpots,
                    isCurved: false,
                    color: _forecastColor,
                    barWidth: 2.5,
                    dashArray: [5, 5],
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (s, _) => s.x.toInt() == lastIdx + 1,
                      getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                          radius: 5,
                          color: AppColors.background,
                          strokeColor: _forecastColor,
                          strokeWidth: 2.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppColors.onSurface, 'Gerçekleşen', dashed: false),
              const SizedBox(width: 18),
              _legend(_forecastColor, 'Tahmin', dashed: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label, {required bool dashed}) {
    return Row(
      children: [
        Container(width: 16, height: dashed ? 0 : 3,
            decoration: dashed
                ? BoxDecoration(border: Border(top: BorderSide(color: c, width: 2.5, style: BorderStyle.solid)))
                : BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(fontSize: 11.5, color: AppColors.outline)),
      ],
    );
  }

  // ---- Harcama hızı ----
  Widget _velocityCard(ForecastModel f) {
    final day = DateTime.now().day;
    final dailyAvg = day > 0 ? f.currentMonthSpent / day : 0.0;
    final activeIdx = switch (f.velocity) {
      'Düşük' => 0,
      'Normal' => 1,
      'Yüksek' => 2,
      _ => 1,
    };
    final segColors = [_okColor, AppColors.warn, AppColors.error, AppColors.surfaceContainerHigh];
    final labelColor = switch (f.velocity) {
      'Düşük' => _okColor,
      'Yüksek' => AppColors.error,
      _ => AppColors.warn,
    };
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: labelColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.bolt, color: labelColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Harcama Hızı: ${f.velocity}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                const SizedBox(height: 3),
                Text('Günlük ort. ${money(dailyAvg)}',
                    style: TextStyle(fontSize: 12.5, color: AppColors.outline)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                              color: segColors[i],
                              borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      if (i < 3) const SizedBox(width: 4),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final e in ['Düşük', 'Normal', 'Yüksek', 'Aşırı'].asMap().entries)
                      Text(e.value,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: e.key == activeIdx
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: e.key == activeIdx
                                  ? labelColor
                                  : AppColors.outline)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Anomaliler ----
  Widget _anomaliesSection(List<AnomalyModel> anomalies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Olağandışı Harcamalar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
            if (anomalies.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99)),
                child: Text('${anomalies.length} uyarı',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (anomalies.isEmpty)
          _card(
            child: Text('Olağandışı harcama tespit edilmedi 👍',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          )
        else
          ...anomalies.map((a) {
            final high = a.severity == 'high';
            final col = high ? AppColors.error : AppColors.warn;
            final cc = categoryColor(a.category);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
                gradient: null,
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 40, color: col),
                  const SizedBox(width: 13),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: cc.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(categoryIcon(a.category), size: 18, color: cc),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.note.isEmpty ? 'Olağandışı ${a.category}' : a.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                        const SizedBox(height: 2),
                        Text(a.reason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.outline)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('−${money(a.amount)}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              fontFeatures: kTnum)),
                      const SizedBox(height: 2),
                      Text(high ? 'YÜKSEK' : 'ORTA',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: col)),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ---- En çok harcanan kategoriler ----
  Widget _topCategories(List<TransactionModel> txs) {
    final byCat = <String, double>{};
    for (final t in txs.where((t) => t.type == 'expense')) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final top = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final list = top.take(5).toList();
    final max = list.isEmpty ? 1.0 : list.first.value;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('En Çok Harcanan Kategoriler',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface)),
          const SizedBox(height: 18),
          if (list.isEmpty)
            Text('Veri yok', style: TextStyle(color: AppColors.onSurfaceVariant))
          else
            for (final e in list) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: categoryColor(e.key),
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 9),
                      Text(e.key,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurface)),
                    ],
                  ),
                  Text(money(e.value),
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                          fontFeatures: kTnum)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: max == 0 ? 0 : e.value / max),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceContainer,
                    color: categoryColor(e.key),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _Data {
  final ForecastModel forecast;
  final List<AnomalyModel> anomalies;
  final List<TransactionModel> txs;
  _Data(this.forecast, this.anomalies, this.txs);
}
