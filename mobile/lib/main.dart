import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api_client.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Türkçe tarih/sayı biçimlendirmesi için yerel veriyi başlat (ay adları vb.).
  await initializeDateFormatting('tr_TR', null);
  runApp(const ExpenzaApp());
}

class ExpenzaApp extends StatelessWidget {
  const ExpenzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: currencyNotifier,
          builder: (context, currency, _) {
            final isDark = mode == ThemeMode.dark;
            // Ekranların okuduğu nötr renkleri aktif moda göre güncelle.
            AppColors.applyMode(isDark);
            return MaterialApp(
              title: 'Expenza',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.fromMode(isDark),
              // Geniş ekranlarda (web/masaüstü) uygulamayı telefon genişliğinde bir
              // çerçeveye alıp ortala; dar ekranlarda (telefon) tam genişlik.
              builder: (context, child) {
                return ColoredBox(
                  color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFE6E9EC),
                  child: Center(
                    child: ClipRect(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                );
              },
              home: _AuthGate(),
            );
          },
        );
      },
    );
  }
}

/// Oturum durumuna göre giriş veya ana kabuğu gösterir.
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    if (!ApiClient.instance.isLoggedIn) {
      return LoginScreen(onLoggedIn: () => setState(() {}));
    }
    return HomeShell(onLogout: () => setState(() {}));
  }
}
