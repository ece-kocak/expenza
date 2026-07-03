import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'analytics_screen.dart';
import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

/// Alt navigasyonlu ana kabuk — 5 sekme + vurgu renkli ekleme (FAB).
class HomeShell extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeShell({super.key, required this.onLogout});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _dashKey = GlobalKey<DashboardScreenState>();
  final _budgetKey = GlobalKey<BudgetsScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();


  static const _items = [
    (Icons.home_outlined, Icons.home, 'Ana Sayfa'),
    (Icons.swap_vert_outlined, Icons.swap_vert, 'İşlemler'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Analitik'),
    (Icons.pie_chart_outline, Icons.pie_chart, 'Bütçe'),
    (Icons.person_outline, Icons.person, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(key: _dashKey, onLogout: widget.onLogout),
      HistoryScreen(
        key: _historyKey,
        onTransactionAdded: () {
          _dashKey.currentState?.refresh();
          _budgetKey.currentState?.refresh();
        },
      ),
      AnalyticsScreen(),
      BudgetsScreen(key: _budgetKey),
      ProfileScreen(onLogout: widget.onLogout),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.navBg,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < _items.length; i++)
                  _navItem(i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final active = _index == i;
    final color = active ? AppColors.primary : AppColors.outline;
    final (outlined, filled, label) = _items[i];
    return Expanded(
      child: Press(
        onTap: () => setState(() => _index = i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? filled : outlined, size: 21, color: color),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

/// Sekmelerde ortak kullanılan sade üst başlık.
class ExpenzaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const ExpenzaAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.background,
      elevation: 0,
      title: Text(title,
          style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 20)),
      actions: actions,
    );
  }
}
