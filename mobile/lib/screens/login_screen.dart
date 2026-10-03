import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

/// Giriş + kayıt ekranı — "Quiet Premium" tasarım (segment kontrolü, ikonlu alanlar).
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'test@expenza.com');
  final _pass = TextEditingController(text: 'secret1');
  final _name = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ApiClient.instance;
      if (_isRegister) {
        await api.register(_email.text.trim(), _pass.text, _name.text.trim());
      }
      await api.login(_email.text.trim(), _pass.text);
      widget.onLoggedIn();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tema düğmesi (sağ üst)
              Align(
                alignment: Alignment.centerRight,
                child: Press(
                  onTap: () => setState(toggleThemeMode),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceContainer),
                    ),
                    child: Icon(
                        isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        size: 18,
                        color: AppColors.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Marka
              Rise(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.account_balance_wallet,
                          color: AppColors.onPrimary, size: 30),
                    ),
                    const SizedBox(height: 28),
                    Text('Expenza',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: AppColors.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                        _isRegister
                            ? 'Birkaç saniyede hesabını oluştur.'
                            : 'Hesabına giriş yap, paranı kontrol et.',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Segment kontrolü
              Rise(delayMs: 50, child: _segmented()),
              const SizedBox(height: 28),

              // Form
              Rise(
                delayMs: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isRegister) ...[
                      _field('AD SOYAD', _name, Icons.person_outline,
                          hint: 'Defne Kaya'),
                      const SizedBox(height: 16),
                    ],
                    _field('E-POSTA', _email, Icons.mail_outline,
                        hint: 'defne@ornek.com',
                        keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _passwordField(),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    color: AppColors.error, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    _submitButton(),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Alt geçiş (büyük yazı boyutunda taşmasın diye Wrap)
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        _isRegister
                            ? 'Zaten hesabın var mı?'
                            : 'Hesabın yok mu?',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.onSurfaceVariant)),
                    Press(
                      onTap: () => setState(() => _isRegister = !_isRegister),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(_isRegister ? 'Giriş Yap' : 'Kayıt Ol',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmented() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment:
                _isRegister ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _segTab('Giriş Yap', !_isRegister,
                  () => setState(() => _isRegister = false)),
              _segTab('Kayıt Ol', _isRegister,
                  () => setState(() => _isRegister = true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, IconData icon,
      {String? hint, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.outline)),
        const SizedBox(height: 8),
        _fieldBox(
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.outline),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: keyboard,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.onSurface),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle:
                        TextStyle(color: AppColors.outline, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PAROLA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.outline)),
            if (!_isRegister)
              Press(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Şifre sıfırlama yakında'))),
                child: Text('Şifremi unuttum',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _fieldBox(
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: AppColors.outline),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pass,
                  obscureText: _obscure,
                  style: TextStyle(fontSize: 14, color: AppColors.onSurface),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '••••••••',
                    hintStyle:
                        TextStyle(color: AppColors.outline, fontSize: 14),
                  ),
                ),
              ),
              Press(
                onTap: () => setState(() => _obscure = !_obscure),
                child: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppColors.outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: child,
    );
  }

  Widget _submitButton() {
    return Press(
      onTap: _busy ? null : _submit,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onPrimary))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isRegister ? 'Kayıt Ol' : 'Giriş Yap',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward,
                        size: 18, color: AppColors.onPrimary),
                  ],
                ),
        ),
      ),
    );
  }
}
