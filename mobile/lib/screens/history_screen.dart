import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'add_transaction_screen.dart';
import 'dashboard_screen.dart' show categoryColor, categoryIcon, money;

/// Tam işlem geçmişi — premium: tarihe göre gruplu, arama, kategori çipleri,
/// sola kaydır→sil, dokun→düzenle.
class HistoryScreen extends StatefulWidget {
  final VoidCallback? onTransactionAdded;
  const HistoryScreen({super.key, this.onTransactionAdded});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  late Future<List<TransactionModel>> _future;
  String? _category;
  String _query = '';
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<TransactionModel>> _load() =>
      ApiClient.instance.getTransactions(category: _category, q: _query);

  void refresh() => setState(() { _future = _load(); });

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = v.trim();
      refresh();
    });
  }

  Future<void> _edit(TransactionModel tx) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => AddTransactionScreen(existing: tx)));
    if (ok == true) {
      refresh();
      widget.onTransactionAdded?.call();
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
    if (added == true) {
      refresh();
      widget.onTransactionAdded?.call();
    }
  }

  /// occurred_on (YYYY-MM-DD) -> "Bugün" / "Dün" / "12 Haziran".
  String _dateLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    return DateFormat('d MMMM', 'tr_TR').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      body: Column(
        children: [
          // ---- Başlık ----
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
            child: FutureBuilder<List<TransactionModel>>(
              future: _future,
              builder: (context, snap) {
                final count = snap.data?.length ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('İşlemler',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1,
                                color: AppColors.onSurface)),
                        const SizedBox(height: 6),
                        Text(
                            '${DateFormat('MMMM yyyy', 'tr_TR').format(DateTime.now())} · $count işlem',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.outline)),
                      ],
                    ),
                    Press(
                      onTap: () => themeModeNotifier.value =
                          isDark ? ThemeMode.light : ThemeMode.dark,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.surfaceContainer)),
                        child: Icon(
                            isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 18,
                            color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ---- Arama ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: AppColors.outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style:
                          TextStyle(fontSize: 14, color: AppColors.onSurface),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'İşlem veya not ara…',
                        hintStyle:
                            TextStyle(color: AppColors.outline, fontSize: 14),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    Press(
                      onTap: () {
                        _searchCtrl.clear();
                        _query = '';
                        refresh();
                      },
                      child: Icon(Icons.cancel,
                          size: 18, color: AppColors.outline),
                    ),
                ],
              ),
            ),
          ),

          // ---- Kategori çipleri ----
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              children: [
                _chip('Tümü', null),
                ...kCategories.map((c) => _chip(c, c)),
              ],
            ),
          ),

          // ---- Liste ----
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => refresh(),
              color: AppColors.onSurface,
              backgroundColor: AppColors.surface,
              child: FutureBuilder<List<TransactionModel>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: AppColors.onSurface));
                  }
                  final txs = snap.data ?? [];
                  if (txs.isEmpty) return _empty();
                  return _groupedList(txs);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 96),
        child: Press(
          onTap: _openAdd,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, color: AppColors.onPrimary, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final active = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Press(
        onTap: () => setState(() {
          _category = value;
          refresh();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: active
                    ? Colors.transparent
                    : AppColors.surfaceContainerHigh),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: categoryColor(value), shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupedList(List<TransactionModel> txs) {
    // Tarihe göre grupla (backend zaten tarihe göre azalan sıralı döner).
    final groups = <String, List<TransactionModel>>{};
    for (final t in txs) {
      groups.putIfAbsent(_dateLabel(t.occurredOn), () => []).add(t);
    }

    final children = <Widget>[];
    groups.forEach((label, items) {
      final net = items.fold(
          0.0, (s, t) => s + (t.type == 'income' ? t.amount : -t.amount));
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.outline)),
            Text('${net < 0 ? '−' : '+'}${money(net)}',
                style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.outline,
                    fontFeatures: kTnum)),
          ],
        ),
      ));
      children.addAll(items.map(_txRow));
    });

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: children,
    );
  }

  Widget _txRow(TransactionModel t) {
    final isIncome = t.type == 'income';
    final color = categoryColor(t.category);
    final time = DateTime.tryParse(t.occurredOn);
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
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
      confirmDismiss: (_) => _confirmDelete(t),
      onDismissed: (_) async {
        await ApiClient.instance.deleteTransaction(t.id);
        refresh();
      },
      child: Press(
        onTap: () => _edit(t),
        child: Container(
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(categoryIcon(t.category), size: 19, color: color),
              ),
              const SizedBox(width: 14),
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
                    Text(
                        '${t.category}${time != null ? ' · ${DateFormat('HH:mm').format(time)}' : ''}',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.outline)),
                  ],
                ),
              ),
              Text('${isIncome ? '+' : '−'}${money(t.amount)}',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isIncome ? color : AppColors.onSurface,
                      fontFeatures: kTnum)),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(TransactionModel t) async {
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
                  Text('İşlemi sil?',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 6),
                  Text(
                      '"${t.note.isEmpty ? t.category : t.note}" kalıcı olarak silinecek.',
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

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.search_off, size: 40, color: AppColors.outline),
        const SizedBox(height: 14),
        Center(
            child: Text('Sonuç bulunamadı',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant))),
        const SizedBox(height: 4),
        Center(
            child: Text('Farklı bir arama veya kategori dene.',
                style: TextStyle(fontSize: 12.5, color: AppColors.outline))),
      ],
    );
  }
}
