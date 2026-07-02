import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';

const _okColor = Color(0xFF46F1C5);
const _infoColor = Color(0xFF6EA8FE);

/// Profil — premium: kullanıcı kartı, finansal içgörüler, ayarlar, çıkış.
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_Data> _future;
  bool _notif = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final api = ApiClient.instance;
    final r = await Future.wait([api.getMe(), api.getInsights()]);
    return _Data(r[0] as ({String email, String displayName}),
        r[1] as List<InsightModel>);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
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
            final me = snap.data?.me;
            final insights = snap.data?.insights ?? [];
            final name = (me?.displayName.isNotEmpty ?? false)
                ? me!.displayName
                : 'Kullanıcı';

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
              children: [
                // Başlık
                Rise(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Profil',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1,
                              color: AppColors.onSurface)),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.surfaceContainer)),
                        child: Icon(Icons.settings_outlined,
                            size: 19, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Kullanıcı kartı
                Rise(delayMs: 40, child: _userCard(name, me?.email ?? '')),
                const SizedBox(height: 24),

                // İçgörüler
                Rise(
                  delayMs: 80,
                  child: Text('Senin İçin İçgörüler',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                ),
                const SizedBox(height: 12),
                if (snap.connectionState == ConnectionState.waiting)
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: AppColors.onSurface),
                  ))
                else if (insights.isEmpty)
                  _insightShell(AppColors.outline, Icons.info_outline,
                      'Birkaç işlem ekledikçe içgörüler burada görünecek.')
                else
                  ...insights.map(_insightCard),
                const SizedBox(height: 26),

                // Ayarlar
                Rise(
                  delayMs: 140,
                  child: Text('Ayarlar',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                ),
                const SizedBox(height: 12),
                Rise(delayMs: 160, child: _settings(isDark)),
                const SizedBox(height: 18),

                // Çıkış
                Press(
                  onTap: () {
                    ApiClient.instance.logout();
                    widget.onLogout();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, size: 18, color: AppColors.error),
                        const SizedBox(width: 9),
                        Text('Çıkış Yap',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _userCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.center,
            child: Text(_initials(name),
                style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppColors.outline)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: _okColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: _okColor),
                      const SizedBox(width: 5),
                      Text('Premium üye',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _okColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
        ],
      ),
    );
  }

  Color _toneColor(String tone) => switch (tone) {
        'good' => _okColor,
        'warn' => AppColors.warn,
        _ => _infoColor,
      };

  IconData _iconFor(String name) => switch (name) {
        'trending_up' => Icons.trending_up,
        'trending_down' => Icons.trending_down,
        'savings' => Icons.savings,
        'pie_chart' => Icons.pie_chart,
        'category' => Icons.category,
        'warning' => Icons.warning_amber_rounded,
        _ => Icons.lightbulb_outline,
      };

  Widget _insightCard(InsightModel ins) {
    final color = _toneColor(ins.tone);
    return _insightShell(color, _iconFor(ins.icon), ins.text, title: ins.title);
  }

  Widget _insightShell(Color color, IconData icon, String text,
      {String? title}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                ],
                Text(text,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.glassBorder)),
        title: Text(title,
            style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
        content: Text(message,
            style: TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Kapat',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.glassBorder)),
          title: Text('Para Birimi Seçin',
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _currencyOption(context, 'Türk Lirası (₺)', '₺'),
              _currencyOption(context, 'Dolar (\$)', '\$'),
              _currencyOption(context, 'Euro (€)', '€'),
              _currencyOption(context, 'Sterlin (£)', '£'),
            ],
          ),
        );
      },
    );
  }

  Widget _currencyOption(BuildContext context, String label, String symbol) {
    final active = currencyNotifier.value == symbol;
    return ListTile(
      title: Text(label, style: TextStyle(color: AppColors.onSurface, fontSize: 14)),
      trailing: active ? Icon(Icons.check, color: AppColors.primary, size: 18) : null,
      onTap: () {
        currencyNotifier.value = symbol;
        Navigator.of(context).pop();
        setState(() {});
      },
    );
  }

  Widget _settings(bool isDark) {
    final curVal = currencyNotifier.value;
    final curLabel = curVal == '₺'
        ? 'Türk Lirası (₺)'
        : curVal == '\$'
            ? 'Dolar (\$)'
            : curVal == '€'
                ? 'Euro (€)'
                : 'Sterlin (£)';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _settingRow(
            _infoColor,
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            'Tema',
            subtitle: isDark ? 'Koyu mod' : 'Açık mod',
            trailing: _miniSwitch(isDark, (v) {
              themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            }),
          ),
          _divider(),
          _settingRow(_okColor, Icons.attach_money, 'Para Birimi',
              value: curLabel, chevron: true, onTap: () {
            _showCurrencyDialog(context);
          }),
          _divider(),
          _settingRow(const Color(0xFFB68CF0), Icons.grid_view, 'Kategoriler',
              value: '8 kategori', chevron: true, onTap: () {
            _showInfoDialog(context, 'Kategoriler',
                'Aktif Kategoriler:\n• Yemek\n• Ulaşım\n• Faturalar\n• Eğlence\n• Sağlık\n• Eğitim\n• Alışveriş\n• Diğer');
          }),
          _divider(),
          _settingRow(
            const Color(0xFFF0B36B),
            Icons.notifications_outlined,
            'Bildirimler',
            subtitle: _notif ? 'Bütçe ve anomali uyarıları' : 'Kapalı',
            trailing: _miniSwitch(_notif, (v) => setState(() => _notif = v)),
          ),
          _divider(),
          _settingRow(AppColors.outline, Icons.info_outline, 'Sürüm',
              value: 'v0.1.0'),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.only(left: 64),
        child: Container(height: 1, color: AppColors.glassBorder),
      );

  Widget _settingRow(Color iconColor, IconData icon, String title,
      {String? subtitle,
      String? value,
      bool chevron = false,
      Widget? trailing,
      VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: AppColors.outline)),
                ],
              ],
            ),
          ),
          if (value != null)
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant)),
          if (chevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
          ],
          if (trailing != null) trailing,
        ],
      ),
    );

    if (onTap != null) {
      return Press(onTap: onTap, child: row);
    }
    return row;
  }

  Widget _miniSwitch(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
                color: value ? AppColors.onPrimary : AppColors.background,
                shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _Data {
  final ({String email, String displayName}) me;
  final List<InsightModel> insights;
  _Data(this.me, this.insights);
}
